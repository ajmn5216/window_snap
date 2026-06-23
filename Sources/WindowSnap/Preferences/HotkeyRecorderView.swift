import AppKit
import Carbon.HIToolbox

/// A small focusable control that records a global hotkey. Click it, then press a
/// modifier+key combination. Press Delete to clear, Escape to cancel.
final class HotkeyRecorderView: NSView {
    var combo: HotKeyCombo? { didSet { needsDisplay = true } }
    var onChange: ((HotKeyCombo?) -> Void)?

    private var recording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 2 : 1
        path.stroke()

        let text: String
        let color: NSColor
        if recording {
            text = "Press keys… (⎋ cancel, ⌫ clear)"
            color = .secondaryLabelColor
        } else if let combo {
            text = combo.displayString
            color = .labelColor
        } else {
            text = "Click to record"
            color = .secondaryLabelColor
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: color,
        ]
        let string = text as NSString
        let size = string.size(withAttributes: attrs)
        string.draw(at: CGPoint(x: 8, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording = true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }

        if Int(event.keyCode) == kVK_Escape {
            recording = false
            return
        }
        if Int(event.keyCode) == kVK_Delete {
            combo = nil
            onChange?(nil)
            recording = false
            return
        }

        let mods = KeyCodes.carbonModifiers(from: event.modifierFlags)
        // Require at least one of control/option/command so we don't capture
        // ordinary typing keys.
        let needed = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)
        guard mods & needed != 0 else {
            NSSound.beep()
            return
        }
        let new = HotKeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods)
        combo = new
        onChange?(new)
        recording = false
    }
}
