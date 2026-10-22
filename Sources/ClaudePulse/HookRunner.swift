import Foundation

/// `ClaudePulse --hook <Event>`: reads Claude Code's hook JSON from stdin, folds it into the session's
/// record and writes it atomically. Never fails the hook: every path returns 0.
enum HookRunner {
    static let sessionsDirectory: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ClaudePulse/sessions", isDirectory: true)

    static func eventFrom(hookName: String, payload: [String: Any]) -> HookEvent? {
        switch hookName {
        case "SessionStart": return .sessionStart
        case "UserPromptSubmit": return .userPromptSubmit
        case "PreToolUse": return .preToolUse
        case "PostToolUse": return .postToolUse
        case "SubagentStart": return .subagentStart
        case "SubagentStop": return .subagentStop
        case "Stop": return .stop
        case "SessionEnd": return .sessionEnd
        case "Notification": return .notification(notificationKind(payload["notification_type"] as? String))
        default: return nil
        }
    }

    private static func notificationKind(_ type: String?) -> NotificationKind {
        switch type {
        case nil, "permission_prompt", "elicitation_dialog": .needsInput
        case "idle_prompt": .idleReminder
        default: .other
        }
    }

    static func run(arguments: [String], stdin: Data, directory: URL, now: Date, pid: Int32?) -> Int32 {
        guard let flag = arguments.firstIndex(of: "--hook"), arguments.indices.contains(flag + 1),
              let payload = (try? JSONSerialization.jsonObject(with: stdin)) as? [String: Any],
              let event = eventFrom(hookName: arguments[flag + 1], payload: payload),
              let sessionID = payload["session_id"] as? String, isSafeFileName(sessionID)
        else { return 0 }
        let cwd = payload["cwd"] as? String ?? ""
        let file = directory.appendingPathComponent("\(sessionID).json")
        try? SessionLock.run(directory: directory, sessionID: sessionID) {
            let existing = SessionStore.decode(try? Data(contentsOf: file))
            guard var next = reduce(existing, event: event, sessionID: sessionID, cwd: cwd,
                                    pid: pid, terminalID: nil, now: now) else {
                try? FileManager.default.removeItem(at: file)
                return
            }
            let transcript = payload["transcript_path"] as? String
            if let name = transcriptValue(path: transcript, type: "custom-title", key: "customTitle") {
                next.name = name
            }
            if let color = transcriptValue(path: transcript, type: "agent-color", key: "agentColor") {
                next.color = color
            }
            try SessionStore.encode(next).write(to: file, options: .atomic)
        }
        if event == .sessionEnd { SessionLock.remove(directory: directory, sessionID: sessionID) }
        return 0
    }

    /// The last `key` of a `type` entry in the transcript's tail. Claude Code appends one entry per `/rename`
    /// (`custom-title`) or `/color` (`agent-color`).
    static func transcriptValue(path: String?, type: String, key: String) -> String? {
        guard let path, let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let window: UInt64 = 256 * 1024
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > window ? size - window : 0)
        guard let data = try? handle.readToEnd(), let text = String(bytes: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n").reversed() where line.contains("\"\(type)\"") {
            guard let entry = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
                  entry["type"] as? String == type,
                  let value = entry[key] as? String, !value.isEmpty else { continue }
            return value
        }
        return nil
    }

    private static func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\0") && name != "." && name != ".."
    }
}
