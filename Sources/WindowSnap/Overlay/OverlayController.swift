import AppKit

/// A transparent, click-through window that draws the current layout's zones and
/// highlights one of them. Used during Shift+drag.
final class OverlayController {
    private var window: NSWindow?
    private let view = OverlayView()

    /// Show the overlay covering `screen`, drawing `zones`, with `highlight` (an
    /// index into `zones`) emphasized. Re-uses the window across calls.
    func show(on screen: NSScreen, zones: [Zone], gap: CGFloat, highlight: Int?) {
        let window = ensureWindow()
        if window.frame != screen.frame {
            window.setFrame(screen.frame, display: false)
        }
        view.screen = screen
        view.zones = zones
        view.gap = gap
        view.highlight = highlight
        view.needsDisplay = true
        if !window.isVisible {
            window.orderFrontRegardless()
        }
    }

    func updateHighlight(_ index: Int?) {
        guard view.highlight != index else { return }
        view.highlight = index
        view.needsDisplay = true
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let w = NSWindow(contentRect: .zero, styleMask: .borderless,
                         backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.level = .init(Int(CGWindowLevelForKey(.overlayWindow)))
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        w.contentView = view
        window = w
        return w
    }
}

/// Draws zones in flipped (top-left origin) coordinates so it matches `FracRect`.
final class OverlayView: NSView {
    var screen: NSScreen?
    var zones: [Zone] = []
    var gap: CGFloat = 8
    var highlight: Int?

    override var isFlipped: Bool { true }

    /// View-space rect for a fractional zone, accounting for the menu bar / Dock
    /// insets between the screen's full frame and its visible frame.
    func viewRect(for frac: FracRect) -> CGRect {
        guard let screen else { return .zero }
        let frame = screen.frame
        let vis = screen.visibleFrame
        let leftInset = vis.minX - frame.minX
        let topInset = frame.maxY - vis.maxY
        let visW = vis.width
        let visH = vis.height
        let inset = gap / 2
        return CGRect(
            x: leftInset + frac.x * visW + inset,
            y: topInset + frac.y * visH + inset,
            width: frac.w * visW - gap,
            height: frac.h * visH - gap
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        for (index, zone) in zones.enumerated() {
            let rect = viewRect(for: zone.rect)
            let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
            let isHot = index == highlight

            if isHot {
                NSColor.controlAccentColor.withAlphaComponent(0.45).setFill()
            } else {
                NSColor.white.withAlphaComponent(0.12).setFill()
            }
            path.fill()

            (isHot ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.5)).setStroke()
            path.lineWidth = isHot ? 3 : 1.5
            path.stroke()

            drawLabel(zone.name, in: rect, emphasized: isHot)
        }
    }

    private func drawLabel(_ text: String, in rect: CGRect, emphasized: Bool) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: emphasized ? 22 : 16, weight: emphasized ? .semibold : .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(emphasized ? 0.95 : 0.7),
        ]
        let string = text as NSString
        let size = string.size(withAttributes: attrs)
        let point = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        string.draw(at: point, withAttributes: attrs)
    }
}
