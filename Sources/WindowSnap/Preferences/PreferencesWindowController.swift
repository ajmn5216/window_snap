import AppKit

/// Preferences window: gap, launch-at-login, Shift+drag toggle, and a fully
/// remappable list of keyboard shortcuts.
final class PreferencesWindowController: NSWindowController {
    private var gapLabel: NSTextField!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = "WindowSnap Preferences"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI()
    }

    func show() {
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let window else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(sectionHeader("General"))

        // Gap.
        let gapStack = NSStackView()
        gapStack.orientation = .horizontal
        gapStack.spacing = 8
        let gapTitle = label("Gap between zones:")
        let slider = NSSlider(value: AppState.shared.settings.gap, minValue: 0, maxValue: 30,
                              target: self, action: #selector(gapChanged(_:)))
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        gapLabel = label("\(Int(AppState.shared.settings.gap)) px")
        gapStack.addArrangedSubview(gapTitle)
        gapStack.addArrangedSubview(slider)
        gapStack.addArrangedSubview(gapLabel)
        stack.addArrangedSubview(gapStack)

        // Toggles.
        let loginCheck = checkbox("Launch at login", action: #selector(toggleLogin(_:)))
        loginCheck.state = LaunchAtLogin.isEnabled ? .on : .off
        stack.addArrangedSubview(loginCheck)

        let dragCheck = checkbox("Enable Shift + drag overlay snapping", action: #selector(toggleDrag(_:)))
        dragCheck.state = AppState.shared.settings.shiftDragEnabled ? .on : .off
        stack.addArrangedSubview(dragCheck)

        stack.addArrangedSubview(spacer(8))
        stack.addArrangedSubview(sectionHeader("Keyboard Shortcuts"))
        stack.addArrangedSubview(label("Click a field, then press a modifier + key combination."))

        for cmd in Presets.commands {
            stack.addArrangedSubview(hotkeyRow(for: cmd))
        }

        let reset = NSButton(title: "Reset Shortcuts to Defaults", target: self,
                             action: #selector(resetHotkeys))
        reset.bezelStyle = .rounded
        stack.addArrangedSubview(spacer(8))
        stack.addArrangedSubview(reset)

        // Scroll view.
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let clip = scroll.contentView
        scroll.documentView = stack

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            stack.topAnchor.constraint(equalTo: clip.topAnchor),
        ])

        window.contentView = scroll
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
        ])
    }

    private func hotkeyRow(for cmd: SnapCommand) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        let title = label(cmd.title)
        title.widthAnchor.constraint(equalToConstant: 250).isActive = true
        title.lineBreakMode = .byTruncatingTail

        let recorder = HotkeyRecorderView()
        recorder.widthAnchor.constraint(equalToConstant: 160).isActive = true
        recorder.combo = AppState.shared.hotkey(for: cmd.id)
        recorder.onChange = { combo in
            AppState.shared.update { settings in
                if let combo {
                    settings.hotkeys[cmd.id.rawValue] = combo
                } else {
                    // Explicit clear: store a sentinel "no key" by removing both
                    // override and relying on default? Use modifiers=0 to mean
                    // "disabled" so it overrides a non-nil default.
                    settings.hotkeys[cmd.id.rawValue] = HotKeyCombo(keyCode: 0, modifiers: 0)
                }
            }
        }
        row.addArrangedSubview(title)
        row.addArrangedSubview(recorder)
        return row
    }

    // MARK: - Actions

    @objc private func gapChanged(_ sender: NSSlider) {
        let value = sender.doubleValue.rounded()
        gapLabel.stringValue = "\(Int(value)) px"
        AppState.shared.update { $0.gap = value }
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        let on = sender.state == .on
        let ok = LaunchAtLogin.set(on)
        AppState.shared.update { $0.launchAtLogin = ok && on }
        if !ok { sender.state = LaunchAtLogin.isEnabled ? .on : .off }
    }

    @objc private func toggleDrag(_ sender: NSButton) {
        AppState.shared.update { $0.shiftDragEnabled = sender.state == .on }
    }

    @objc private func resetHotkeys() {
        AppState.shared.update { $0.hotkeys = [:] }
        // Rebuild UI to reflect defaults.
        buildUI()
    }

    // MARK: - Small builders

    private func sectionHeader(_ text: String) -> NSTextField {
        let field = label(text)
        field.font = .boldSystemFont(ofSize: 13)
        return field
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 12)
        return field
    }

    private func checkbox(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(checkboxWithTitle: title, target: self, action: action)
        return b
    }

    private func spacer(_ height: CGFloat) -> NSView {
        let v = NSView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }
}
