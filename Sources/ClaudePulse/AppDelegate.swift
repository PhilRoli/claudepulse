import AppKit
import MenuBarKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configStore = AppConfigStore()
    private var config = AppConfig()
    private let store = SessionStore(directory: HookRunner.sessionsDirectory)
    private let statusBar = StatusBarController()
    private let focuser = GhosttyFocuser()
    private let presenter = NotificationPresenter()
    private lazy var notifications = NotificationManager(scheduler: UNUserNotificationCenter.current())
    private var records: [SessionRecord] = []
    private var prefs: PreferencesWindowController?
    private var wakeObserver: NSObjectProtocol?
    /// NSAppleScript is not documented as thread-safe, so clicks are focused one at a time.
    private let focusQueue = DispatchQueue(label: "ClaudePulse.focus", qos: .userInitiated)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make(appName: "ClaudePulse")
        config = configStore.load()
        UNUserNotificationCenter.current().delegate = presenter
        if config.notificationsEnabled { notifications.requestAuthorization() }

        statusBar.rows = { [unowned self] in MenuModel.rows(for: self.records, now: Date()) }
        statusBar.onSelect = { [unowned self] in self.select(sessionID: $0) }
        statusBar.onPreferences = { [unowned self] in self.showPreferences() }
        presenter.onSelect = { [unowned self] in self.select(sessionID: $0) }
        store.onChange = { [unowned self] in self.refresh() }
        wakeObserver = observeWake { [weak self] in self?.refresh() }

        records = store.load()
        statusBar.setTitle(MenuModel.title(for: records))
        store.startWatching()
    }

    private func refresh() {
        let old = records
        records = store.load()
        statusBar.setTitle(MenuModel.title(for: records))
        let due = NotificationManager.shouldNotify(old: old, new: records, enabled: config.notificationsEnabled)
        if !due.isEmpty { notifications.post(due) }
    }

    private func select(sessionID: String) {
        guard let record = records.first(where: { $0.sessionID == sessionID }) else { return }
        let focuser = self.focuser
        focusQueue.async { [weak self] in
            let outcome = focuser.focus(record: record)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.statusBar.automationDenied = outcome == .automationDenied
                    self?.store.markSeen(sessionID: sessionID)
                    self?.refresh()
                }
            }
        }
    }

    private func showPreferences() {
        if prefs == nil {
            let controller = PreferencesWindowController(config: config, loginItem: LoginItemController())
            controller.onChange = { [unowned self] in
                self.config = $0
                self.configStore.save($0)
                if $0.notificationsEnabled { self.notifications.requestAuthorization() }
            }
            controller.onHooksRemoved = { [unowned self] in
                self.store.clearAll()
                self.refresh()
            }
            prefs = controller
        }
        prefs?.show()
    }
}
