import AppKit
import MenuBarKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    var onChange: ((AppConfig) -> Void)?
    var onHooksRemoved: (() -> Void)?

    private var config: AppConfig
    private let loginItem: LoginItemController
    private let notifyCheck = NSButton(checkboxWithTitle: "Enabled", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let hooksStatus = PreferencesLayout.label("")
    private let installButton = NSButton(title: "Install", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove", target: nil, action: nil)

    private let settingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    init(config: AppConfig, loginItem: LoginItemController) {
        self.config = config
        self.loginItem = loginItem
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "ClaudePulse"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        notifyCheck.target = self
        notifyCheck.action = #selector(notifyToggled)
        loginCheck.target = self
        loginCheck.action = #selector(loginToggled)
        installButton.target = self
        installButton.action = #selector(installHooks)
        removeButton.target = self
        removeButton.action = #selector(removeHooks)

        let hookButtons = NSStackView(views: [installButton, removeButton])
        hookButtons.spacing = 8
        let stack = NSStackView(views: [
            PreferencesLayout.sectionLabel("Notifications"), notifyCheck,
            PreferencesLayout.sectionLabel("Startup"), loginCheck,
            PreferencesLayout.sectionLabel("Claude Code hooks"), hooksStatus, hookButtons,
            PreferencesLayout.separator(width: 260), PreferencesLayout.versionLabel()
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        PreferencesLayout.pinAndFit(stack, in: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        notifyCheck.state = config.notificationsEnabled ? .on : .off
        loginCheck.state = loginItem.isEnabled ? .on : .off
        refreshHooksStatus()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshHooksStatus(error: String? = nil) {
        if let error {
            hooksStatus.stringValue = error
            return
        }
        let installed = HookInstaller.isInstalled(in: try? Data(contentsOf: settingsURL.resolvingSymlinksInPath()))
        hooksStatus.stringValue = installed ? "Installed" : "Not installed"
        installButton.isEnabled = !installed
        removeButton.isEnabled = installed
    }

    @objc private func notifyToggled() {
        config.notificationsEnabled = notifyCheck.state == .on
        onChange?(config)
    }

    @objc private func loginToggled() {
        if !loginItem.setEnabled(loginCheck.state == .on) { loginCheck.state = loginItem.isEnabled ? .on : .off }
    }

    @objc private func installHooks() {
        let path = Bundle.main.executablePath ?? CommandLine.arguments[0]
        do {
            try HookInstaller.installToDisk(settingsURL: settingsURL, executablePath: path)
            refreshHooksStatus()
            hooksStatus.stringValue = "Installed. Restart running sessions."
        } catch {
            refreshHooksStatus(error: "settings.json is not valid JSON")
        }
    }

    @objc private func removeHooks() {
        do {
            try HookInstaller.removeFromDisk(settingsURL: settingsURL)
            onHooksRemoved?()
            refreshHooksStatus()
        } catch {
            refreshHooksStatus(error: "settings.json is not valid JSON")
        }
    }
}
