import Foundation
import ServiceManagement

/// Wraps `SMAppService` (macOS 13+) to register the app as a login item.
/// Requires the app to be a bundle; works for the `WindowSnap.app` produced by
/// `build_app.sh`.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("WindowSnap: launch-at-login change failed: \(error)")
            return false
        }
    }
}
