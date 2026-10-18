import MenuBarKit
import UserNotifications

struct NotificationMessage: Equatable {
    var title: String
    var body: String
}

final class NotificationManager {
    private let scheduler: NotificationScheduler
    private var authRequested = false

    init(scheduler: NotificationScheduler) {
        self.scheduler = scheduler
    }

    /// Sessions that newly entered needs input or finished since `old`.
    static func shouldNotify(old: [SessionRecord], new: [SessionRecord], enabled: Bool) -> [SessionRecord] {
        guard enabled else { return [] }
        let before = Dictionary(old.map { ($0.sessionID, $0.state) }, uniquingKeysWith: { first, _ in first })
        return new.filter { record in
            guard record.state == .needsInput || record.state == .finished else { return false }
            return before[record.sessionID] != record.state
        }
    }

    static func message(for record: SessionRecord) -> NotificationMessage? {
        let name = MenuModel.rows(for: [record], now: record.updatedAt).first?.title ?? record.cwd
        switch record.state {
        case .needsInput: return NotificationMessage(title: "\(name) needs input", body: record.cwd)
        case .finished: return NotificationMessage(title: "\(name) finished", body: record.cwd)
        case .working, .waitingForSubagent: return nil
        }
    }

    func post(_ records: [SessionRecord]) {
        requestAuthorization()
        for record in records {
            guard let message = Self.message(for: record) else { continue }
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.userInfo = ["sessionID": record.sessionID]
            scheduler.add(UNNotificationRequest(identifier: record.sessionID, content: content, trigger: nil),
                          withCompletionHandler: nil)
        }
    }

    /// Called at launch so the permission prompt doesn't swallow the first notification.
    func requestAuthorization() {
        guard !authRequested else { return }
        authRequested = true
        Task { [scheduler] in _ = try? await scheduler.requestAuthorization(options: [.alert, .sound]) }
    }
}

/// Shows banners while frontmost and routes a click back to the session.
final class NotificationPresenter: BannerNotificationPresenter {
    var onSelect: ((String) -> Void)?

    override func handleClick(userInfo: [AnyHashable: Any]) {
        guard let id = userInfo["sessionID"] as? String else { return }
        DispatchQueue.main.async { [weak self] in self?.onSelect?(id) }
    }
}
