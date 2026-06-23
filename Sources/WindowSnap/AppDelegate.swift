import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusController = StatusItemController()
    private let hotKeyManager = HotKeyManager()
    private let dragMonitor = DragMonitor()

    private lazy var preferences = PreferencesWindowController()
    private lazy var editor = ZoneEditorWindowController()

    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController.install()
        statusController.onOpenPreferences = { [weak self] in self?.preferences.show() }
        statusController.onOpenEditor = { [weak self] in self?.editor.show() }

        registerHotkeys()

        NotificationCenter.default.addObserver(
            self, selector: #selector(stateChanged),
            name: .appStateChanged, object: nil)

        // Carbon hotkeys work without Accessibility, but moving windows and the
        // drag tap require it. Prompt and enable AX-dependent features once granted.
        if AccessibilityPermissions.isTrusted(prompt: true) {
            enableAXFeatures()
        } else {
            AccessibilityPermissions.showOnboardingAlert()
            startPermissionPolling()
        }
    }

    // MARK: - Permission flow

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard AccessibilityPermissions.isTrusted else { return }
            timer.invalidate()
            self?.permissionTimer = nil
            self?.enableAXFeatures()
        }
    }

    private func enableAXFeatures() {
        updateDragMonitor()
    }

    // MARK: - State

    @objc private func stateChanged() {
        registerHotkeys()
        updateDragMonitor()
    }

    private func registerHotkeys() {
        hotKeyManager.unregisterAll()
        let engine = AppState.shared.snapEngine
        for id in CommandID.allCases {
            guard let combo = AppState.shared.hotkey(for: id) else { continue }
            hotKeyManager.register(combo) { engine.run(id) }
        }
    }

    private func updateDragMonitor() {
        guard AccessibilityPermissions.isTrusted else { return }
        if AppState.shared.settings.shiftDragEnabled {
            dragMonitor.start()
        } else {
            dragMonitor.stop()
        }
    }
}
