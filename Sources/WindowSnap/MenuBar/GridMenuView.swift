import AppKit

/// A clickable mini-map of the active layout embedded in the status menu. Click a
/// zone to snap the captured window into it. Drawn in flipped coordinates.
final class GridMenuView: NSView {
    var zones: [Zone] = [] { didSet { needsDisplay = true } }
    var aspect: CGFloat = 21.0 / 9.0 { didSet { invalidateIntrinsicContentSize() } }

    /// Called with the chosen zone's fractional rect.
    var onPick: ((FracRect) -> Void)?

    private var hoverIndex: Int?
    private let horizontalInset: CGFloat = 14
    private let verticalInset: CGFloat = 8

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let tracking = NSTrackingArea(rect: .zero,
                                      options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                      owner: self, userInfo: nil)
        addTrackingArea(tracking)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        let width: CGFloat = 240
        let mapWidth = width - horizontalInset * 2
        let mapHeight = mapWidth / aspect
        return NSSize(width: width, height: mapHeight + verticalInset * 2)
    }

    private var mapRect: CGRect {
        bounds.insetBy(dx: horizontalInset, dy: verticalInset)
    }

    private func rect(for frac: FracRect) -> CGRect {
        let m = mapRect
        let pad: CGFloat = 2
        return CGRect(
            x: m.minX + frac.x * m.width + pad,
            y: m.minY + frac.y * m.height + pad,
            width: frac.w * m.width - pad * 2,
            height: frac.h * m.height - pad * 2
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        // Screen backdrop.
        let backdrop = NSBezierPath(roundedRect: mapRect, xRadius: 6, yRadius: 6)
        NSColor.windowBackgroundColor.withAlphaComponent(0.6).setFill()
        backdrop.fill()

        for (index, zone) in zones.enumerated() {
            let r = rect(for: zone.rect)
            let path = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
            let isHover = index == hoverIndex
            (isHover ? NSColor.controlAccentColor.withAlphaComponent(0.85)
                     : NSColor.controlAccentColor.withAlphaComponent(0.30)).setFill()
            path.fill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = isHover ? 2 : 1
            path.stroke()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(event)
    }

    override func mouseExited(with event: NSEvent) {
        if hoverIndex != nil { hoverIndex = nil; needsDisplay = true }
    }

    private func updateHover(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let new = zones.firstIndex { rect(for: $0.rect).contains(point) }
        if new != hoverIndex { hoverIndex = new; needsDisplay = true }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = zones.firstIndex(where: { rect(for: $0.rect).contains(point) }) else { return }
        onPick?(zones[index].rect)
        enclosingMenuItem?.menu?.cancelTracking()
    }
}
