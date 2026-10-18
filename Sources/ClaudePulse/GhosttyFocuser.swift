import AppKit

/// Brings the Ghostty terminal for a session to the front via Ghostty's AppleScript dictionary.
final class GhosttyFocuser {
    enum Outcome: Equatable {
        case focused, activatedOnly, automationDenied
    }

    static let bundleID = "com.mitchellh.ghostty"
    private static let automationDeniedCode = -1743

    /// Blocking (AppleScript round-trip): call off the main thread.
    func focus(record: SessionRecord) -> Outcome {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first != nil else {
            activate()
            return .activatedOnly
        }
        let terminals: [GhosttyTerminal]
        switch listTerminals() {
        case .failure(let code):
            activate()
            return code == Self.automationDeniedCode ? .automationDenied : .activatedOnly
        case .success(let list):
            terminals = list
        }
        guard let target = TerminalMatcher.match(record: record, terminals: terminals),
              target.id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else {
            activate()
            return .activatedOnly
        }
        var error: NSDictionary?
        let focusScript = """
        with timeout of 3 seconds
        tell application "Ghostty" to focus terminal id "\(target.id)"
        end timeout
        """
        NSAppleScript(source: focusScript)?.executeAndReturnError(&error)
        activate()
        return error == nil ? .focused : .activatedOnly
    }

    private enum ListResult {
        case success([GhosttyTerminal])
        case failure(Int)
    }

    private func listTerminals() -> ListResult {
        var error: NSDictionary?
        let script = NSAppleScript(source: """
        with timeout of 3 seconds
        tell application "Ghostty" to get {id, working directory} of every terminal
        end timeout
        """)
        guard let result = script?.executeAndReturnError(&error), error == nil else {
            return .failure((error?[NSAppleScript.errorNumber] as? Int) ?? 0)
        }
        guard result.numberOfItems == 2, let ids = result.atIndex(1), let dirs = result.atIndex(2) else {
            return .success([])
        }
        let terminals = (0..<ids.numberOfItems).compactMap { i -> GhosttyTerminal? in
            guard let id = ids.atIndex(i + 1)?.stringValue,
                  let dir = dirs.atIndex(i + 1)?.stringValue else { return nil }
            return GhosttyTerminal(id: id, workingDirectory: dir)
        }
        return .success(terminals)
    }

    /// `NSRunningApplication.activate()` is ignored when the caller is an inactive accessory app, so go through
    /// the workspace, which also launches Ghostty when it isn't running.
    private func activate() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
