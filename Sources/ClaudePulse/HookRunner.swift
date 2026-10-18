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
        case "SubagentStart": return .subagentStart
        case "SubagentStop": return .subagentStop
        case "Stop": return .stop
        case "SessionEnd": return .sessionEnd
        case "Notification":
            return .notification(isIdleReminder: payload["notification_type"] as? String == "idle_prompt")
        default: return nil
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
        do {
            let existing = SessionStore.decode(try? Data(contentsOf: file))
            guard let next = reduce(existing, event: event, sessionID: sessionID, cwd: cwd,
                                    pid: pid, terminalID: nil, now: now) else {
                try? FileManager.default.removeItem(at: file)
                return 0
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try SessionStore.encode(next).write(to: file, options: .atomic)
        } catch {}
        return 0
    }

    private static func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\0") && name != "." && name != ".."
    }
}
