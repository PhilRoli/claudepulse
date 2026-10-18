import Foundation
import MenuBarKit

struct AppConfig: Codable, Equatable {
    var notificationsEnabled = false
}

extension AppConfig: DefaultInitializable {}
typealias AppConfigStore = JSONDefaultsStore<AppConfig>
