import AppKit

/// Interactive canvas for the zone editor. Shows the display area (aspect-fit)
/// and lets the user select, move, and resize zones, snapping to a grid.
final class ZoneCanvasView: NSView {
    var zones: [Zone] = [] { didSet { needsDisplay = true } }
    var selectedIndex: Int? { didSet { needsDisplay = true } }
    var aspect: CGFloat = 21.0 / 9.0 { didSet { needsDisplay = true } }

    /// Grid divisions used for snapping (e.g. 24 → snap to 1/24 increments).
    var snapDivisions: Int = 24

    /// Called whenever zones change via interaction.
    var onChange: (() -> Void)?

    override var isFlipped: Bool { true }

    private let handleSize: CGFloat = 10
    private enum DragMode { case none, move, resize(corner: Corner) }
    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    private var dragMode: DragMode = .none
    private var dragStart: CGPoint = .zero
    private var originalRect: FracRect = FracRect(0, 0, 0, 0)

    // MARK: - Coordinate mapping

    /// The letterboxed rect (in view coords) that represents the display.
    private var displayRect: CGRect {
        let inset: CGFloat = 16
        let avail = bounds.insetBy(dx: inset, dy: inset)
        var w = avail.width
        var h = w / aspect
        if h > avail.height {
            h = avail.height
            w = h * aspect
        }
        return CGRect(x: avail.midX - w / 2, y: avail.midY - h / 2, width: w, height: h)
    }

    private func rect(for frac: FracRect) -> CGRect {
        let d = displayRect
        return CGRect(x: d.minX + frac.x * d.width,
                      y: d.minY + frac.y * d.height,
                      width: frac.w * d.width,
                      height: frac.h * d.height)
    }

    private func frac(fromViewPoint p: CGPoint) -> CGPoint {
        let d = displayRect
        return CGPoint(x: (p.x - d.minX) / d.width, y: (p.y - d.minY) / d.height)
    }

    private func snap(_ value: Double) -> Double {
        let step = 1.0 / Double(snapDivisions)
        return (value / step).rounded() * step
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let d = displayRect
        let frame = NSBezierPath(rect: d)
        NSColor.black.withAlphaComponent(0.65).setFill()
        frame.fill()

        // Grid guides.
        NSColor.white.withAlphaComponent(0.06).setStroke()
        let grid = NSBezierPath()
        let cols = snapDivisions
        for i in 1..<cols {
            let x = d.minX + d.width * CGFloat(i) / CGFloat(cols)
            grid.move(to: CGPoint(x: x, y: d.minY))
            grid.line(to: CGPoint(x: x, y: d.maxY))
        }
        grid.lineWidth = 1
        grid.stroke()

        for (index, zone) in zones.enumerated() {
            let r = rect(for: zone.rect)
            let path = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
            let selected = index == selectedIndex
            (selected ? NSColor.controlAccentColor.withAlphaComponent(0.45)
                      : NSColor.controlAccentColor.withAlphaComponent(0.20)).setFill()
            path.fill()
            (selected ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.5)).setStroke()
            path.lineWidth = selected ? 2.5 : 1
            path.stroke()

            // Name.
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.9),
            ]
            (zone.name as NSString).draw(at: CGPoint(x: r.minX + 6, y: r.minY + 4), withAttributes: attrs)

            if selected {
                for corner in cornerPoints(of: r) {
                    let h = CGRect(x: corner.x - handleSize / 2, y: corner.y - handleSize / 2,
                                   width: handleSize, height: handleSize)
                    NSColor.white.setFill()
                    NSColor.controlAccentColor.setStroke()
                    let hp = NSBezierPath(rect: h)
                    hp.fill(); hp.stroke()
                }
            }
        }
    }

    private func cornerPoints(of r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
         CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)]
    }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)

        // If a zone is selected, check its corner handles first.
        if let sel = selectedIndex, sel < zones.count {
            let r = rect(for: zones[sel].rect)
            let corners: [(Corner, CGPoint)] = [
                (.topLeft, CGPoint(x: r.minX, y: r.minY)),
                (.topRight, CGPoint(x: r.maxX, y: r.minY)),
                (.bottomLeft, CGPoint(x: r.minX, y: r.maxY)),
                (.bottomRight, CGPoint(x: r.maxX, y: r.maxY)),
            ]
            for (corner, point) in corners where hypot(point.x - p.x, point.y - p.y) <= handleSize {
                dragMode = .resize(corner: corner)
                dragStart = p
                originalRect = zones[sel].rect
                return
            }
        }

        // Otherwise select the top-most zone under the cursor.
        if let index = zones.lastIndex(where: { rect(for: $0.rect).contains(p) }) {
            selectedIndex = index
            dragMode = .move
            dragStart = p
            originalRect = zones[index].rect
        } else {
            selectedIndex = nil
            dragMode = .none
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let sel = selectedIndex, sel < zones.count else { return }
        let p = convert(event.locationInWindow, from: nil)
        let d = displayRect
        let dx = Double((p.x - dragStart.x) / d.width)
        let dy = Double((p.y - dragStart.y) / d.height)

        var r = originalRect
        switch dragMode {
        case .move:
            r.x = clamp(originalRect.x + dx, 0, 1 - originalRect.w)
            r.y = clamp(originalRect.y + dy, 0, 1 - originalRect.h)
            r.x = snap(r.x); r.y = snap(r.y)
        case .resize(let corner):
            applyResize(&r, corner: corner, dx: dx, dy: dy)
        case .none:
            return
        }
        zones[sel].rect = r
        needsDisplay = true
        onChange?()
    }

    override func mouseUp(with event: NSEvent) {
        dragMode = .none
    }

    private func applyResize(_ r: inout FracRect, corner: Corner, dx: Double, dy: Double) {
        let minSize = 1.0 / Double(snapDivisions)
        var left = originalRect.x
        var top = originalRect.y
        var right = originalRect.x + originalRect.w
        var bottom = originalRect.y + originalRect.h

        switch corner {
        case .topLeft: left += dx; top += dy
        case .topRight: right += dx; top += dy
        case .bottomLeft: left += dx; bottom += dy
        case .bottomRight: right += dx; bottom += dy
        }
        left = snap(clamp(left, 0, 1)); right = snap(clamp(right, 0, 1))
        top = snap(clamp(top, 0, 1)); bottom = snap(clamp(bottom, 0, 1))
        if right - left < minSize { if left == originalRect.x { right = left + minSize } else { left = right - minSize } }
        if bottom - top < minSize { if top == originalRect.y { bottom = top + minSize } else { top = bottom - minSize } }
        r.x = left; r.y = top; r.w = right - left; r.h = bottom - top
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }
}
