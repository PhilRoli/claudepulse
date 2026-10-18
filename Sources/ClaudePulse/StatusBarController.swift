import AppKit
import MenuBarKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    var onSelect: ((String) -> Void)?
    var onPreferences: (() -> Void)?
    var rows: () -> [SessionRow] = { [] }
    var automationDenied = false

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var sessionItems: [(item: NSMenuItem, id: String)] = []
    private let ticker = MenuOpenTicker()

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        setTitle(StatusTitle(symbol: "◌", tint: .normal))
    }

    /// Colour comes from the attributed title's foreground only; `contentTintColor` renders the item black.
    func setTitle(_ title: StatusTitle) {
        let color: NSColor? = switch title.tint {
        case .normal: nil
        case .green: .systemGreen
        case .orange: .systemOrange
        }
        var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]
        if let color { attributes[.foregroundColor] = color }
        statusItem.button?.attributedTitle = NSAttributedString(string: title.symbol, attributes: attributes)
    }

    func menuNeedsUpdate(_ menu: NSMenu) { rebuild() }

    func menuWillOpen(_ menu: NSMenu) {
        ticker.start { [weak self] in self?.tick() }
    }

    func menuDidClose(_ menu: NSMenu) { ticker.stop() }

    private func rebuild() {
        menu.removeAllItems()
        sessionItems = []
        let current = rows()
        if current.isEmpty {
            menu.addItem(.info(NSAttributedString(string: "No active sessions", attributes: [.font: NSFont.systemFont(ofSize: 13)])))
        }
        for row in current {
            let item = NSMenuItem.item("", action: #selector(selected(_:)), target: self)
            item.representedObject = row.sessionID
            item.attributedTitle = title(for: row)
            sessionItems.append((item, row.sessionID))
            menu.addItem(item)
        }
        if automationDenied {
            menu.addItem(.separator())
            menu.addItem(.info(NSAttributedString(string: "Allow Automation for Ghostty in System Settings", attributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.systemOrange])))
        }
        menu.addItem(.separator())
        menu.addItem(.item("Preferences…", action: #selector(preferences), key: ",", target: self))
        menu.addItem(.item("Quit", action: #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private func tick() {
        let byID = Dictionary(uniqueKeysWithValues: rows().map { ($0.sessionID, $0) })
        for (item, id) in sessionItems {
            if let row = byID[id] { item.attributedTitle = title(for: row) }
        }
    }

    private func title(for row: SessionRow) -> NSAttributedString {
        let title = NSMutableAttributedString(string: row.title, attributes: [.font: NSFont.systemFont(ofSize: 13)])
        title.append(NSAttributedString(string: "   \(row.detail)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor]))
        return title
    }

    @objc private func selected(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { onSelect?(id) }
    }

    @objc private func preferences() { onPreferences?() }
}
