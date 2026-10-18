import Foundation

enum StatusTint: Equatable {
    case normal, green, orange
}

struct StatusTitle: Equatable {
    var symbol: String
    var tint: StatusTint
}

struct SessionRow: Equatable {
    var sessionID: String
    var title: String
    var detail: String
}

enum MenuModel {
    /// What the icon shows: the most urgent state across sessions. Seen-finished sessions count as idle.
    static func title(for records: [SessionRecord]) -> StatusTitle {
        let states = Set(records.compactMap(effectiveState))
        if states.contains(.needsInput) { return StatusTitle(symbol: "!", tint: .orange) }
        if states.contains(.waitingForSubagent) { return StatusTitle(symbol: "◐", tint: .normal) }
        if states.contains(.finished) { return StatusTitle(symbol: "✓", tint: .green) }
        if states.contains(.working) { return StatusTitle(symbol: "●", tint: .normal) }
        return StatusTitle(symbol: "◌", tint: .normal)
    }

    static func rows(for records: [SessionRecord], now: Date) -> [SessionRow] {
        records.map { record in
            let name = (record.cwd as NSString).lastPathComponent
            return SessionRow(sessionID: record.sessionID,
                              title: name.isEmpty ? "/" : name,
                              detail: "\(label(record)) · \(elapsed(now.timeIntervalSince(record.updatedAt)))")
        }
    }

    private static func effectiveState(_ record: SessionRecord) -> SessionState? {
        record.state == .finished && record.seen ? nil : record.state
    }

    private static func label(_ record: SessionRecord) -> String {
        switch effectiveState(record) {
        case .working: "working"
        case .waitingForSubagent: "waiting for subagent"
        case .needsInput: "needs input"
        case .finished: "finished"
        case nil: "idle"
        }
    }

    static func elapsed(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }
}
