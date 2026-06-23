import AppKit

extension Notification.Name {
    /// Posted whenever settings or layouts change so UI can refresh.
    static let appStateChanged = Notification.Name("WindowSnap.appStateChanged")
}

/// Central, in-memory application state: settings + layouts, plus the shared
/// `WindowManager` and `SnapEngine`. Mutations persist to disk and broadcast a
/// change notification.
final class AppState {
    static let shared = AppState()

    private(set) var settings: Settings
    private(set) var userLayouts: [Layout]

    let windowManager = WindowManager()
    let snapEngine: SnapEngine

    /// Built-in layouts first, then user layouts.
    var layouts: [Layout] { Presets.builtInLayouts + userLayouts }

    var activeLayout: Layout {
        layouts.first(where: { $0.id == settings.activeLayoutID }) ?? layouts[0]
    }

    private init() {
        let config = Store.shared.load()
        var settings = config.settings
        if settings.activeLayoutID == nil
            || !(Presets.builtInLayouts + config.userLayouts).contains(where: { $0.id == settings.activeLayoutID }) {
            settings.activeLayoutID = Presets.defaultActiveLayoutID
        }
        self.settings = settings
        self.userLayouts = config.userLayouts
        self.snapEngine = SnapEngine(windowManager: windowManager)
    }

    // MARK: - Mutation

    func update(_ mutate: (inout Settings) -> Void) {
        mutate(&settings)
        persist()
        notify()
    }

    func setActiveLayout(_ id: UUID) {
        settings.activeLayoutID = id
        persist()
        notify()
    }

    func upsertUserLayout(_ layout: Layout) {
        if let idx = userLayouts.firstIndex(where: { $0.id == layout.id }) {
            userLayouts[idx] = layout
        } else {
            userLayouts.append(layout)
        }
        persist()
        notify()
    }

    func deleteUserLayout(_ id: UUID) {
        userLayouts.removeAll { $0.id == id }
        if settings.activeLayoutID == id {
            settings.activeLayoutID = Presets.defaultActiveLayoutID
        }
        persist()
        notify()
    }

    /// The effective hotkey for a command: user override, else the default.
    /// An override with `keyCode == 0` is a "disabled" sentinel (the user cleared
    /// a default), so it suppresses the default and returns `nil`.
    func hotkey(for id: CommandID) -> HotKeyCombo? {
        if let override = settings.hotkeys[id.rawValue] {
            return override.keyCode == 0 ? nil : override
        }
        return Presets.command(id).defaultHotkey
    }

    private func persist() {
        Store.shared.save(.init(settings: settings, userLayouts: userLayouts))
    }

    private func notify() {
        NotificationCenter.default.post(name: .appStateChanged, object: nil)
    }
}
