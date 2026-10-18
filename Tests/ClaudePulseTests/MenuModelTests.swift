import XCTest
@testable import ClaudePulse

final class MenuModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    private func record(_ state: SessionState, id: String = "a", cwd: String = "/Users/x/Dev/foo",
                        seen: Bool = false, age: TimeInterval = 0) -> SessionRecord {
        SessionRecord(sessionID: id, cwd: cwd, pid: 1, terminalID: nil, state: state, subagents: 0,
                      seen: seen, updatedAt: now.addingTimeInterval(-age))
    }

    func testEmptyIsIdle() {
        XCTAssertEqual(MenuModel.title(for: []), StatusTitle(symbol: "◌", tint: .normal))
    }

    func testPriorityOrder() {
        let all = [record(.working, id: "w"), record(.finished, id: "f"),
                   record(.waitingForSubagent, id: "s"), record(.needsInput, id: "n")]
        XCTAssertEqual(MenuModel.title(for: all).symbol, "!")
        XCTAssertEqual(MenuModel.title(for: Array(all.dropLast())).symbol, "◐")
        XCTAssertEqual(MenuModel.title(for: [all[0], all[1]]).symbol, "✓")
        XCTAssertEqual(MenuModel.title(for: [all[0]]).symbol, "●")
    }

    func testTints() {
        XCTAssertEqual(MenuModel.title(for: [record(.needsInput)]).tint, .orange)
        XCTAssertEqual(MenuModel.title(for: [record(.finished)]).tint, .green)
    }

    func testSeenFinishedCountsAsIdle() {
        let seen = record(.finished, seen: true)
        XCTAssertEqual(MenuModel.title(for: [seen]).symbol, "◌")
        XCTAssertEqual(MenuModel.rows(for: [seen], now: now).first?.detail, "idle · 0s")
    }

    func testRowFormatting() {
        let rows = MenuModel.rows(for: [record(.needsInput, age: 120), record(.working, id: "b", age: 45),
                                        record(.waitingForSubagent, id: "c", age: 3 * 3600)], now: now)
        XCTAssertEqual(rows[0].title, "foo")
        XCTAssertEqual(rows[0].detail, "needs input · 2m")
        XCTAssertEqual(rows[1].detail, "working · 45s")
        XCTAssertEqual(rows[2].detail, "waiting for subagent · 3h")
    }

    func testRowsKeepSessionID() {
        XCTAssertEqual(MenuModel.rows(for: [record(.working, id: "zz")], now: now).first?.sessionID, "zz")
    }

    func testRootCwdFallsBackToSlash() {
        XCTAssertEqual(MenuModel.rows(for: [record(.working, cwd: "/")], now: now).first?.title, "/")
    }

    func testElapsedUsesStateSinceNotLastUpdate() {
        var r = record(.working, age: 5)
        r.stateSince = now.addingTimeInterval(-120)
        XCTAssertEqual(MenuModel.rows(for: [r], now: now).first?.detail, "working · 2m")
    }
}
