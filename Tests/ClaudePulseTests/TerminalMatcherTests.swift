import XCTest
@testable import ClaudePulse

final class TerminalMatcherTests: XCTestCase {
    private func record(cwd: String, terminalID: String? = nil) -> SessionRecord {
        SessionRecord(sessionID: "a", cwd: cwd, pid: 1, terminalID: terminalID, state: .working,
                      subagents: 0, seen: false, updatedAt: Date())
    }

    private let terminals = [GhosttyTerminal(id: "t1", workingDirectory: "/Users/x/foo"),
                             GhosttyTerminal(id: "t2", workingDirectory: "/Users/x/bar"),
                             GhosttyTerminal(id: "t3", workingDirectory: "/Users/x/bar")]

    func testRecordedTerminalIDWins() {
        let r = record(cwd: "/Users/x/foo", terminalID: "t3")
        XCTAssertEqual(TerminalMatcher.match(record: r, terminals: terminals)?.id, "t3")
    }

    func testMatchesByCwd() {
        XCTAssertEqual(TerminalMatcher.match(record: record(cwd: "/Users/x/foo"), terminals: terminals)?.id, "t1")
    }

    func testDuplicateCwdPicksFirst() {
        XCTAssertEqual(TerminalMatcher.match(record: record(cwd: "/Users/x/bar"), terminals: terminals)?.id, "t2")
    }

    func testNormalisesTrailingSlashAndFileURL() {
        let t = [GhosttyTerminal(id: "t", workingDirectory: "file:///Users/x/foo/")]
        XCTAssertEqual(TerminalMatcher.match(record: record(cwd: "/Users/x/foo"), terminals: t)?.id, "t")
    }

    func testNoMatchIsNil() {
        XCTAssertNil(TerminalMatcher.match(record: record(cwd: "/nope"), terminals: terminals))
        XCTAssertNil(TerminalMatcher.match(record: record(cwd: "/nope"), terminals: []))
    }

    func testStaleTerminalIDFallsBackToCwd() {
        let r = record(cwd: "/Users/x/foo", terminalID: "gone")
        XCTAssertEqual(TerminalMatcher.match(record: r, terminals: terminals)?.id, "t1")
    }
}
