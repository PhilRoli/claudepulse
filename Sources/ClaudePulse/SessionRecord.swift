import Foundation

enum SessionState: String, Codable {
    case working, waitingForSubagent, needsInput, finished
}

enum HookEvent: Equatable {
    case sessionStart, userPromptSubmit, preToolUse, subagentStart, subagentStop
    case notification(isIdleReminder: Bool), stop, sessionEnd
}

struct SessionRecord: Codable, Equatable {
    var sessionID: String
    var cwd: String
    var pid: Int32?
    var terminalID: String?
    var state: SessionState
    var subagents: Int
    var seen: Bool
    var updatedAt: Date
}
