import AppKit

/// Visual editor for creating and saving custom zone layouts.
final class ZoneEditorWindowController: NSWindowController {
    private var draft = Layout(name: "New Layout", zones: [], isBuiltIn: false)

    private let canvas = ZoneCanvasView()
    private let layoutPopup = NSPopUpButton()
    private let nameField = NSTextField(string: "")
    private let colsStepperField = NSTextField(string: "3")
    private let rowsStepperField = NSTextField(string: "1")
    private let deleteLayoutButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Zone Editor"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 420)
        self.init(window: window)
        buildUI()
        loadDraft(from: AppState.shared.activeLayout)
    }

    func show() {
        rebuildLayoutPopup()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let window else { return }
        if let screen = NSScreen.main {
            canvas.aspect = max(1.2, screen.frame.width / screen.frame.height)
        }
        canvas.onChange = { [weak self] in self?.updateStatus() }
        canvas.translatesAutoresizingMaskIntoConstraints = false

        // Row 1: layout selection + name.
        layoutPopup.target = self
        layoutPopup.action = #selector(selectLayout)
        nameField.placeholderString = "Layout name"
        nameField.target = self
        nameField.action = #selector(nameEdited)
        let newBtn = button("New", #selector(newLayout))
        let dupBtn = button("Duplicate", #selector(duplicateLayout))
        deleteLayoutButton.title = "Delete"
        deleteLayoutButton.bezelStyle = .rounded
        deleteLayoutButton.target = self
        deleteLayoutButton.action = #selector(deleteLayout)

        let row1 = NSStackView(views: [label("Layout:"), layoutPopup, newBtn, dupBtn, deleteLayoutButton,
                                       label("Name:"), nameField])
        row1.orientation = .horizontal
        row1.spacing = 6
        nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        layoutPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true

        // Row 2: grid generation + zone ops.
        colsStepperField.widthAnchor.constraint(equalToConstant: 40).isActive = true
        rowsStepperField.widthAnchor.constraint(equalToConstant: 40).isActive = true
        let genBtn = button("Generate Grid", #selector(generateGrid))
        let addBtn = button("Add Zone", #selector(addZone))
        let delZoneBtn = button("Delete Zone", #selector(deleteZone))
        let renameBtn = button("Rename Zone", #selector(renameZone))
        let row2 = NSStackView(views: [label("Columns:"), colsStepperField, label("Rows:"), rowsStepperField,
                                       genBtn, NSView(), addBtn, delZoneBtn, renameBtn])
        row2.orientation = .horizontal
        row2.spacing = 6

        // Row 3 (bottom): help + save.
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        let revertBtn = button("Revert", #selector(revert))
        let saveBtn = button("Save", #selector(save))
        let saveActivateBtn = button("Save & Activate", #selector(saveAndActivate))
        saveActivateBtn.keyEquivalent = "\r"
        let row3 = NSStackView(views: [statusLabel, NSView(), revertBtn, saveBtn, saveActivateBtn])
        row3.orientation = .horizontal
        row3.spacing = 8

        let container = NSStackView(views: [row1, row2, canvas, row3])
        container.orientation = .vertical
        container.spacing = 10
        container.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.setHuggingPriority(.defaultLow, for: .vertical)

        window.contentView = container
        let content = window.contentView!
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            container.topAnchor.constraint(equalTo: content.topAnchor),
            container.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])

        updateStatus()
    }

    private func rebuildLayoutPopup() {
        layoutPopup.removeAllItems()
        for l in AppState.shared.layouts {
            layoutPopup.addItem(withTitle: l.isBuiltIn ? "\(l.name)  (built-in)" : "\(l.name)  (custom)")
            layoutPopup.lastItem?.representedObject = l.id.uuidString
        }
        if let idx = AppState.shared.layouts.firstIndex(where: { $0.id == draft.id }) {
            layoutPopup.selectItem(at: idx)
        }
    }

    // MARK: - Draft management

    private func loadDraft(from layout: Layout) {
        draft = layout
        nameField.stringValue = layout.name
        canvas.zones = layout.zones
        canvas.selectedIndex = layout.zones.isEmpty ? nil : 0
        deleteLayoutButton.isEnabled = !layout.isBuiltIn
        rebuildLayoutPopup()
        updateStatus()
    }

    private func updateStatus() {
        let origin = draft.isBuiltIn ? "built-in (saving creates a custom copy)" : "custom"
        statusLabel.stringValue = "\(canvas.zones.count) zones · \(origin) · drag to move, drag corners to resize, snaps to grid"
    }

    // MARK: - Actions

    @objc private func selectLayout() {
        guard let raw = layoutPopup.selectedItem?.representedObject as? String,
              let id = UUID(uuidString: raw),
              let layout = AppState.shared.layouts.first(where: { $0.id == id }) else { return }
        loadDraft(from: layout)
    }

    @objc private func nameEdited() {
        draft.name = nameField.stringValue
    }

    @objc private func newLayout() {
        loadDraft(from: Layout(name: "New Layout",
                               zones: [Zone(name: "Left", rect: Presets.leftHalf),
                                       Zone(name: "Right", rect: Presets.rightHalf)],
                               isBuiltIn: false))
    }

    @objc private func duplicateLayout() {
        var copy = draft
        copy.id = UUID()
        copy.isBuiltIn = false
        copy.name = draft.name + " copy"
        loadDraft(from: copy)
    }

    @objc private func deleteLayout() {
        guard !draft.isBuiltIn else { return }
        AppState.shared.deleteUserLayout(draft.id)
        loadDraft(from: AppState.shared.activeLayout)
    }

    @objc private func generateGrid() {
        let cols = max(1, min(12, Int(colsStepperField.stringValue) ?? 3))
        let rows = max(1, min(12, Int(rowsStepperField.stringValue) ?? 1))
        var zones: [Zone] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let rect = FracRect(Double(c) / Double(cols), Double(r) / Double(rows),
                                    1.0 / Double(cols), 1.0 / Double(rows))
                let name = rows == 1 ? "\(c + 1)" : "\(r + 1),\(c + 1)"
                zones.append(Zone(name: name, rect: rect))
            }
        }
        canvas.zones = zones
        canvas.selectedIndex = zones.isEmpty ? nil : 0
        updateStatus()
    }

    @objc private func addZone() {
        var zones = canvas.zones
        zones.append(Zone(name: "Zone \(zones.count + 1)", rect: FracRect(0.25, 0.25, 0.5, 0.5)))
        canvas.zones = zones
        canvas.selectedIndex = zones.count - 1
        updateStatus()
    }

    @objc private func deleteZone() {
        guard let sel = canvas.selectedIndex, sel < canvas.zones.count else { return }
        var zones = canvas.zones
        zones.remove(at: sel)
        canvas.zones = zones
        canvas.selectedIndex = zones.isEmpty ? nil : min(sel, zones.count - 1)
        updateStatus()
    }

    @objc private func renameZone() {
        guard let sel = canvas.selectedIndex, sel < canvas.zones.count else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Zone"
        let field = NSTextField(string: canvas.zones[sel].name)
        field.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            var zones = canvas.zones
            zones[sel].name = field.stringValue
            canvas.zones = zones
        }
    }

    @objc private func revert() {
        if let current = AppState.shared.layouts.first(where: { $0.id == draft.id }) {
            loadDraft(from: current)
        }
    }

    @discardableResult
    private func commit() -> UUID {
        draft.name = nameField.stringValue.isEmpty ? "Untitled" : nameField.stringValue
        draft.zones = canvas.zones
        if draft.isBuiltIn {
            draft.id = UUID()
            draft.isBuiltIn = false
            if !draft.name.contains("custom") { draft.name += " (custom)" }
        }
        AppState.shared.upsertUserLayout(draft)
        loadDraft(from: draft)
        return draft.id
    }

    @objc private func save() {
        commit()
        statusLabel.stringValue = "Saved “\(draft.name)”."
    }

    @objc private func saveAndActivate() {
        let id = commit()
        AppState.shared.setActiveLayout(id)
        statusLabel.stringValue = "Saved & activated “\(draft.name)”."
    }

    // MARK: - Builders

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = .systemFont(ofSize: 12)
        return f
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }
}
