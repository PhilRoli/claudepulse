import AppKit
import MenuBarKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make(appName: "ClaudePulse")
        statusItem.button?.title = "◌"
        let menu = NSMenu()
        menu.addItem(.item("Quit ClaudePulse", action: #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
        statusItem.menu = menu
    }
}
