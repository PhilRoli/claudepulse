import Foundation

enum SessionState: String, Codable {
    case working, waitingForSubagent, needsInput, finished
}

/// `needsInput`: a permission prompt or dialog is waiting; `idleReminder`: Claude has been waiting for a prompt;
/// `other`: anything else (e.g. auth success), which never changes state.
enum NotificationKind: Equatable {
    case needsInput, idleReminder, other
}

enum HookEvent: Equatable {
    case sessionStart, userPromptSubmit, preToolUse, postToolUse, subagentStart, subagentStop
    case notification(NotificationKind), stop, sessionEnd
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
    /// When the session first appeared, and when its state last changed. Optional so older files still decode.
    var startedAt: Date?
    var stateSince: Date?
    /// The session's `/rename` title, if any; shown instead of the directory name.
    var name: String?
    /// The session's `/color` name (e.g. "orange"), shown as a dot beside the name.
    var color: String?
}
