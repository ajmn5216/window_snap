import AppKit
import ApplicationServices

/// Owns the menu bar status item and builds its menu on demand.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let engine = AppState.shared.snapEngine

    /// Window focused when the menu opened — used so snaps target the right
    /// window even though opening the menu may shift focus.
    private var capturedWindow: AXUIElement?

    var onOpenPreferences: (() -> Void)?
    var onOpenEditor: (() -> Void)?

    func install() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.3x1",
                                   accessibilityDescription: "WindowSnap")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Menu building

    func menuWillOpen(_ menu: NSMenu) {
        capturedWindow = AppState.shared.windowManager.focusedWindow()
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        if !AccessibilityPermissions.isTrusted {
            let warn = NSMenuItem(title: "⚠️  Grant Accessibility Access…",
                                  action: #selector(grantAccess), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
            menu.addItem(.separator())
        }

        // Active layout grid.
        let layout = AppState.shared.activeLayout
        let header = NSMenuItem(title: "Layout: \(layout.name)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let grid = GridMenuView()
        grid.zones = layout.zones
        if let screen = NSScreen.main {
            grid.aspect = max(1.2, screen.frame.width / screen.frame.height)
        }
        grid.onPick = { [weak self] frac in
            guard let self else { return }
            self.engine.snap(toZone: frac, window: self.capturedWindow)
        }
        grid.frame = NSRect(origin: .zero, size: grid.intrinsicContentSize)
        let gridItem = NSMenuItem()
        gridItem.view = grid
        menu.addItem(gridItem)

        // Switch layout.
        let layoutsItem = NSMenuItem(title: "Switch Layout", action: nil, keyEquivalent: "")
        let layoutsMenu = NSMenu()
        for l in AppState.shared.layouts {
            let item = NSMenuItem(title: l.isBuiltIn ? l.name : "\(l.name)  (custom)",
                                  action: #selector(selectLayout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = l.id.uuidString
            item.state = (l.id == layout.id) ? .on : .off
            layoutsMenu.addItem(item)
        }
        layoutsItem.submenu = layoutsMenu
        menu.addItem(layoutsItem)

        menu.addItem(.separator())

        // Quick snaps.
        addCommand(.maximize, to: menu)
        addCommand(.center, to: menu)
        addCommand(.presentation, to: menu)

        let more = NSMenuItem(title: "More Snaps", action: nil, keyEquivalent: "")
        let moreMenu = NSMenu()
        for id in [CommandID.cycleLeft, .cycleRight, .cycleUp, .cycleDown,
                   .leftHalf, .rightHalf, .topHalf, .bottomHalf,
                   .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter,
                   .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds] {
            addCommand(id, to: moreMenu)
        }
        more.submenu = moreMenu
        menu.addItem(more)

        menu.addItem(.separator())

        let editor = NSMenuItem(title: "Edit Zones…", action: #selector(openEditor), keyEquivalent: "e")
        editor.target = self
        menu.addItem(editor)

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit WindowSnap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func addCommand(_ id: CommandID, to menu: NSMenu) {
        let cmd = Presets.command(id)
        let item = NSMenuItem(title: cmd.title, action: #selector(runCommand(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = id.rawValue
        if let combo = AppState.shared.hotkey(for: id) {
            item.toolTip = combo.displayString
        }
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func runCommand(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = CommandID(rawValue: raw) else { return }
        engine.run(id, window: capturedWindow)
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw) else { return }
        AppState.shared.setActiveLayout(id)
    }

    @objc private func grantAccess() {
        AccessibilityPermissions.isTrusted(prompt: true)
        AccessibilityPermissions.openSettings()
    }

    @objc private func openPreferences() { onOpenPreferences?() }
    @objc private func openEditor() { onOpenEditor?() }
}
