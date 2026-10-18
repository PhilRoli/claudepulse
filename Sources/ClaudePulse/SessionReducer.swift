import Foundation

// Folds one hook event into a session's record. Returns nil when the session ended (delete the file).
// swiftlint:disable:next function_parameter_count cyclomatic_complexity
func reduce(_ record: SessionRecord?, event: HookEvent, sessionID: String, cwd: String,
            pid: Int32?, terminalID: String?, now: Date) -> SessionRecord? {
    if event == .sessionEnd { return nil }
    var next = record ?? SessionRecord(sessionID: sessionID, cwd: cwd, pid: pid, terminalID: terminalID,
                                       state: .working, subagents: 0, seen: false, updatedAt: now,
                                       startedAt: now, stateSince: now)
    let before = (next.state, next.seen)
    // The session's directory is fixed by its first event: Claude may wander into subdirectories later.
    if next.cwd.isEmpty { next.cwd = cwd }
    next.pid = pid
    next.updatedAt = now
    if let terminalID { next.terminalID = terminalID }

    switch event {
    case .sessionStart:
        // A fresh, cleared, compacted or resumed session sits idle until the first prompt.
        next.subagents = 0
        markIdle(&next)
    case .preToolUse, .postToolUse:
        // Tool calls made by a running subagent must not pull the session out of waiting.
        if !(next.state == .waitingForSubagent && next.subagents > 0) { next.state = .working }
    case .userPromptSubmit:
        next.state = .working
        next.subagents = 0
        next.seen = false
    case .subagentStart:
        next.subagents += 1
    case .subagentStop:
        next.subagents = max(0, next.subagents - 1)
        if next.state == .waitingForSubagent, next.subagents == 0 { finish(&next) }
    case .notification(.needsInput):
        next.state = .needsInput
    case .notification(.idleReminder):
        // Claude waiting for a prompt while we think it works means the turn was interrupted.
        if next.state == .working, next.subagents == 0 { markIdle(&next) }
    case .notification(.other):
        break
    case .stop:
        if next.subagents > 0 { next.state = .waitingForSubagent } else { finish(&next) }
    case .sessionEnd:
        break
    }
    if (next.state, next.seen) != before { next.stateSince = now }
    return next
}

private func markIdle(_ record: inout SessionRecord) {
    record.state = .finished
    record.seen = true
}

private func finish(_ record: inout SessionRecord) {
    record.state = .finished
    record.seen = false
}
