import XCTest
@testable import ClaudePulse

final class ClaudeProcessTests: XCTestCase {
    private func lookup(_ table: [Int32: (Int32, String)]) -> (Int32) -> (ppid: Int32, name: String)? {
        { table[$0].map { (ppid: $0.0, name: $0.1) } }
    }

    func testSkipsTransientShellsToClaude() {
        let table: [Int32: (Int32, String)] = [30: (20, "sh"), 20: (10, "zsh"), 10: (1, "claude")]
        XCTAssertEqual(ClaudeProcess.find(from: 30, lookup: lookup(table)), 10)
    }

    func testAcceptsNodeHostedClaude() {
        let table: [Int32: (Int32, String)] = [20: (10, "sh"), 10: (1, "node")]
        XCTAssertEqual(ClaudeProcess.find(from: 20, lookup: lookup(table)), 10)
    }

    func testNotFoundReturnsNil() {
        let table: [Int32: (Int32, String)] = [30: (20, "sh"), 20: (1, "login")]
        XCTAssertNil(ClaudeProcess.find(from: 30, lookup: lookup(table)))
    }

    func testStopsOnCycleAndUnknownProcess() {
        XCTAssertNil(ClaudeProcess.find(from: 5, lookup: lookup([5: (6, "sh"), 6: (5, "sh")])))
        XCTAssertNil(ClaudeProcess.find(from: 5, lookup: lookup([:])))
    }
}
