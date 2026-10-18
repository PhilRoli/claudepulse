import Darwin

/// Finds the Claude Code process that spawned a hook. The hook's direct parent is often a short-lived shell,
/// so recording `getppid()` would make the session look dead immediately.
enum ClaudeProcess {
    private static let names: Set<String> = ["claude", "node"]
    private static let maxDepth = 10

    static func find(from start: Int32, lookup: (Int32) -> (ppid: Int32, name: String)? = systemLookup) -> Int32? {
        var pid = start
        var seen: Set<Int32> = []
        for _ in 0..<maxDepth {
            guard pid > 1, seen.insert(pid).inserted, let info = lookup(pid) else { return nil }
            if names.contains(info.name) { return pid }
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
