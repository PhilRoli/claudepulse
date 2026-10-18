import XCTest
@testable import ClaudePulse

final class SessionReducerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 2_000)

    private func record(_ state: SessionState, subagents: Int = 0, seen: Bool = false) -> SessionRecord {
        SessionRecord(sessionID: "a", cwd: "/p", pid: 1, terminalID: nil,
                      state: state, subagents: subagents, seen: seen, updatedAt: t0)
    }

    private func apply(_ event: HookEvent, to record: SessionRecord?) -> SessionRecord? {
        reduce(record, event: event, sessionID: "a", cwd: "/p", pid: 1, terminalID: nil, now: t1)
    }

    func testUserPromptSubmitResetsToWorking() {
        let r = apply(.userPromptSubmit, to: record(.finished, subagents: 2, seen: true))
        XCTAssertEqual(r?.state, .working)
        XCTAssertEqual(r?.subagents, 0)
        XCTAssertEqual(r?.seen, false)
        XCTAssertEqual(r?.updatedAt, t1)
    }

    func testPreToolUseClearsNeedsInput() {
        XCTAssertEqual(apply(.preToolUse, to: record(.needsInput))?.state, .working)
    }

    func testSubagentToolUseDoesNotLeaveWaiting() {
        let r = apply(.preToolUse, to: record(.waitingForSubagent, subagents: 1))
        XCTAssertEqual(r?.state, .waitingForSubagent)
    }

    func testNotificationWhileWorkingNeedsInput() {
        XCTAssertEqual(apply(.notification(isIdleReminder: false), to: record(.working))?.state, .needsInput)
    }

    func testIdleReminderDoesNotOverwriteFinished() {
        XCTAssertEqual(apply(.notification(isIdleReminder: true), to: record(.finished))?.state, .finished)
    }

    func testNotificationWithOutstandingSubagentKeepsState() {
        let r = apply(.notification(isIdleReminder: false), to: record(.waitingForSubagent, subagents: 1))
        XCTAssertEqual(r?.state, .waitingForSubagent)
    }

    func testStopWithoutSubagentsFinishes() {
        let r = apply(.stop, to: record(.working, seen: true))
        XCTAssertEqual(r?.state, .finished)
        XCTAssertEqual(r?.seen, false)
    }

    func testStopWithSubagentWaits() {
        XCTAssertEqual(apply(.stop, to: record(.working, subagents: 1))?.state, .waitingForSubagent)
    }

    func testSubagentCounting() {
        XCTAssertEqual(apply(.subagentStart, to: record(.working))?.subagents, 1)
        XCTAssertEqual(apply(.subagentStop, to: record(.working, subagents: 0))?.subagents, 0)
        XCTAssertEqual(apply(.subagentStop, to: record(.working, subagents: 2))?.subagents, 1)
    }

    func testLastSubagentStopWhileWaitingFinishes() {
        let r = apply(.subagentStop, to: record(.waitingForSubagent, subagents: 1))
        XCTAssertEqual(r?.state, .finished)
        XCTAssertEqual(r?.subagents, 0)
        XCTAssertEqual(r?.seen, false)
    }

    func testSessionEndDeletes() {
        XCTAssertNil(apply(.sessionEnd, to: record(.working)))
    }

    func testMissingRecordIsCreated() {
        let r = apply(.stop, to: nil)
        XCTAssertEqual(r?.state, .finished)
        XCTAssertEqual(r?.sessionID, "a")
        XCTAssertEqual(r?.cwd, "/p")
    }

    func testSessionStartIsWorking() {
        XCTAssertEqual(apply(.sessionStart, to: nil)?.state, .working)
    }

    func testTerminalIDKeptWhenNewOneIsNil() {
        var existing = record(.working)
        existing.terminalID = "t1"
        XCTAssertEqual(apply(.preToolUse, to: existing)?.terminalID, "t1")
    }
}
