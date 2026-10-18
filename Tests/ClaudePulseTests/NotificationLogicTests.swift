import XCTest
@testable import ClaudePulse

final class NotificationLogicTests: XCTestCase {
    private func record(_ state: SessionState, id: String = "a") -> SessionRecord {
        SessionRecord(sessionID: id, cwd: "/p", pid: 1, terminalID: nil, state: state, subagents: 0,
                      seen: false, updatedAt: Date())
    }

    private func notified(_ old: [SessionRecord], _ new: [SessionRecord], enabled: Bool = true) -> [String] {
        NotificationManager.shouldNotify(old: old, new: new, enabled: enabled).map(\.sessionID)
    }

    func testWorkingToNeedsInputNotifies() {
        XCTAssertEqual(notified([record(.working)], [record(.needsInput)]), ["a"])
    }

    func testUnchangedNeedsInputDoesNotNotify() {
        XCTAssertEqual(notified([record(.needsInput)], [record(.needsInput)]), [])
    }

    func testWaitingToFinishedNotifies() {
        XCTAssertEqual(notified([record(.waitingForSubagent)], [record(.finished)]), ["a"])
    }

    func testWorkingAndWaitingTransitionsDoNotNotify() {
        XCTAssertEqual(notified([record(.working)], [record(.waitingForSubagent)]), [])
        XCTAssertEqual(notified([record(.finished)], [record(.working)]), [])
    }

    func testDisabledReturnsNothing() {
        XCTAssertEqual(notified([record(.working)], [record(.needsInput)], enabled: false), [])
    }

    func testNewSessionAppearingFinishedNotifies() {
        XCTAssertEqual(notified([], [record(.finished, id: "b")]), ["b"])
    }

    func testMessageText() {
        let message = NotificationManager.message(for: SessionRecord(
            sessionID: "a", cwd: "/Users/x/foo", pid: 1, terminalID: nil, state: .needsInput,
            subagents: 0, seen: false, updatedAt: Date()))
        XCTAssertEqual(message?.title, "foo needs input")
        XCTAssertNil(NotificationManager.message(for: record(.working)))
    }
}
