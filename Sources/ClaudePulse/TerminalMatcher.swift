import Foundation

struct GhosttyTerminal: Equatable {
    var id: String
    var workingDirectory: String
}

enum TerminalMatcher {
    /// A recorded terminal id that still exists wins; otherwise the first terminal in the session's cwd.
    static func match(record: SessionRecord, terminals: [GhosttyTerminal]) -> GhosttyTerminal? {
        if let id = record.terminalID, let known = terminals.first(where: { $0.id == id }) { return known }
        let wanted = normalise(record.cwd)
        return terminals.first { normalise($0.workingDirectory) == wanted }
    }

    private static func normalise(_ path: String) -> String {
        var p = path
        if p.hasPrefix("file://") { p = URL(string: p)?.path ?? String(p.dropFirst(7)) }
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p
    }
}
