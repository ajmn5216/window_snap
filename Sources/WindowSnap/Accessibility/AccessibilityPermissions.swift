import AppKit
import ApplicationServices

/// Wraps the Accessibility trust check and the System Settings deep-link.
enum AccessibilityPermissions {
    /// Whether the app is currently trusted to control other apps via AX.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Check trust, optionally showing the system prompt that adds the app to the
    /// Accessibility list in System Settings.
    @discardableResult
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings ▸ Privacy & Security ▸ Accessibility.
    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Present a guidance alert when permission is missing.
    static func showOnboardingAlert() {
        let alert = NSAlert()
        alert.messageText = "WindowSnap needs Accessibility access"
        alert.informativeText = """
        To move and resize windows in other apps, macOS requires you to grant \
        Accessibility permission.

        1. Click "Open System Settings".
        2. Under Privacy & Security ▸ Accessibility, enable WindowSnap.
        3. WindowSnap will start working automatically — no restart needed.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            _ = isTrusted(prompt: true)
            openSettings()
        }
    }
}
