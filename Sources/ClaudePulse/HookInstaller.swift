import Foundation

/// Adds and removes ClaudePulse's entries in Claude Code's user settings, identified by a marker in the command.
enum HookInstaller {
    struct InvalidSettings: Error {}

    static let marker = "# claudepulse"
    static let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "SubagentStart", "SubagentStop",
                         "Notification", "Stop", "SessionEnd"]

    static func install(into settings: Data?, executablePath: String) throws -> Data {
        var root = try parse(settings)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var groups = strip(hooks[event] as? [[String: Any]] ?? [])
            let command = "\"\(executablePath)\" --hook \(event) \(marker)"
            groups.append(["hooks": [["type": "command", "command": command]]])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try serialize(root)
    }

    static func remove(from settings: Data) throws -> Data {
        var root = try parse(settings)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for (event, value) in hooks {
            let groups = strip(value as? [[String: Any]] ?? [])
            hooks[event] = groups.isEmpty ? nil : groups
        }
        root["hooks"] = hooks.isEmpty ? nil : hooks
        return try serialize(root)
    }

    static func isInstalled(in settings: Data?) -> Bool {
        guard let root = try? parse(settings), let hooks = root["hooks"] as? [String: Any] else { return false }
        return events.contains { event in
            (hooks[event] as? [[String: Any]] ?? []).contains { group in
                (group["hooks"] as? [[String: Any]] ?? []).contains(where: isOurs)
            }
        }
    }

    /// Writes through symlinks. A missing file is created; malformed JSON throws and writes nothing.
    static func installToDisk(settingsURL: URL, executablePath: String) throws {
        let target = settingsURL.resolvingSymlinksInPath()
        let updated = try install(into: try? Data(contentsOf: target), executablePath: executablePath)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try updated.write(to: target, options: .atomic)
    }

    static func removeFromDisk(settingsURL: URL) throws {
        let target = settingsURL.resolvingSymlinksInPath()
        guard let data = try? Data(contentsOf: target) else { return }
        try remove(from: data).write(to: target, options: .atomic)
    }

    private static func parse(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InvalidSettings()
        }
        return object
    }

    private static func serialize(_ root: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: root,
                                   options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    private static func isOurs(_ hook: [String: Any]) -> Bool {
        (hook["command"] as? String)?.hasSuffix(marker) == true
    }

    /// Groups with our entries removed; groups left empty are dropped.
    private static func strip(_ groups: [[String: Any]]) -> [[String: Any]] {
        groups.compactMap { group in
            var group = group
            let kept = (group["hooks"] as? [[String: Any]] ?? []).filter { !isOurs($0) }
            if kept.isEmpty && group["hooks"] != nil { return nil }
            group["hooks"] = kept
            return group
        }
    }
}
