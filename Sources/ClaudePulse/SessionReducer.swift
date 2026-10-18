import Foundation

// Folds one hook event into a session's record. Returns nil when the session ended (delete the file).
// swiftlint:disable:next function_parameter_count cyclomatic_complexity
func reduce(_ record: SessionRecord?, event: HookEvent, sessionID: String, cwd: String,
            pid: Int32?, terminalID: String?, now: Date) -> SessionRecord? {
    if event == .sessionEnd { return nil }
    var next = record ?? SessionRecord(sessionID: sessionID, cwd: cwd, pid: pid, terminalID: terminalID,
                                       state: .working, subagents: 0, seen: false, updatedAt: now)
    next.cwd = cwd
    next.pid = pid
    next.updatedAt = now
    if let terminalID { next.terminalID = terminalID }

    switch event {
    case .sessionStart:
        next.state = .working
    case .preToolUse:
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
    case .notification(let isIdleReminder):
        if !isIdleReminder, next.subagents == 0 { next.state = .needsInput }
    case .stop:
        if next.subagents > 0 { next.state = .waitingForSubagent } else { finish(&next) }
    case .sessionEnd:
        break
    }
    return next
}

private func finish(_ record: inout SessionRecord) {
    record.state = .finished
    record.seen = false
}
