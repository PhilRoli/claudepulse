import Darwin
import Foundation

/// Finds the Claude Code process that spawned a hook: the first ancestor that is not a shell. The hook's direct
/// parent is often a short-lived shell, so recording `getppid()` would make the session look dead immediately.
/// Matching on the name "claude" would miss installs whose binary is named after its version.
enum ClaudeProcess {
    private static let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish", "ksh", "tcsh"]
    private static let maxDepth = 10

    static func find(from start: Int32, lookup: (Int32) -> (ppid: Int32, name: String)? = systemLookup) -> Int32? {
        var pid = start
        var seen: Set<Int32> = []
        for _ in 0..<maxDepth {
            guard pid > 1, seen.insert(pid).inserted, let info = lookup(pid) else { return nil }
            if !shells.contains(info.name.trimmingCharacters(in: CharacterSet(charactersIn: "-"))) { return pid }
            pid = info.ppid
        }
        return nil
    }

    static func systemLookup(_ pid: Int32) -> (ppid: Int32, name: String)? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        let name = withUnsafePointer(to: info.pbi_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
        }
        return (Int32(info.pbi_ppid), name)
    }
}
