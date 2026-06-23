import Foundation
import AppKit

/// A rectangle expressed as fractions (0...1) of a reference area.
///
/// Origin is TOP-LEFT (`x` from the left edge, `y` from the top edge) to match
/// the Accessibility coordinate system. This keeps zone math intuitive: a zone
/// pinned to the top-left of the screen is `FracRect(0, 0, w, h)`.
struct FracRect: Codable, Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }
}

/// Coordinate-system helpers.
///
/// macOS has two relevant coordinate spaces:
///  - **Cocoa** (`NSScreen`, `NSWindow`): origin bottom-left, y increases upward,
///    global origin at the bottom-left of the primary display.
///  - **Accessibility / Quartz** (`AXUIElement`, `CGEvent`): origin top-left,
///    y increases downward, global origin at the top-left of the primary display.
///
/// We compute zones from `visibleFrame` (which already excludes the menu bar and
/// Dock) and convert to top-left coordinates before driving the Accessibility API.
enum Geometry {
    /// Height of the global coordinate space — i.e. the height of the primary
    /// display (the one whose Cocoa frame origin is `(0, 0)`).
    static var globalHeight: CGFloat {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        return primary?.frame.maxY ?? 0
    }

    /// Convert a Cocoa (bottom-left origin) rect to a top-left origin rect.
    static func topLeft(from cocoa: NSRect) -> CGRect {
        let y = globalHeight - cocoa.origin.y - cocoa.height
        return CGRect(x: cocoa.origin.x, y: y, width: cocoa.width, height: cocoa.height)
    }

    /// Convert a top-left origin point to a Cocoa (bottom-left origin) point.
    static func cocoaPoint(fromTopLeft p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: globalHeight - p.y)
    }

    /// The screen containing a top-left-origin global point (e.g. a cursor
    /// location from a `CGEvent`).
    static func screen(containingTopLeft point: CGPoint) -> NSScreen? {
        let cocoa = cocoaPoint(fromTopLeft: point)
        return NSScreen.screens.first(where: { NSMouseInRect(cocoa, $0.frame, false) })
            ?? NSScreen.main
    }

    /// Absolute top-left-origin rect for a fractional zone on a given screen,
    /// inset by `gap`. Uses `visibleFrame` so windows never overlap the menu bar
    /// or Dock. The gap is applied as a half-inset per edge, so adjacent zones
    /// are separated by `gap` and screen edges keep a `gap/2` margin.
    static func absoluteRect(for frac: FracRect, on screen: NSScreen, gap: CGFloat) -> CGRect {
        let vis = topLeft(from: screen.visibleFrame)
        var r = CGRect(
            x: vis.origin.x + frac.x * vis.width,
            y: vis.origin.y + frac.y * vis.height,
            width: frac.w * vis.width,
            height: frac.h * vis.height
        )
        let inset = gap / 2.0
        r = r.insetBy(dx: inset, dy: inset)
        // Guard against degenerate sizes from large gaps on tiny zones.
        if r.width < 60 { r.size.width = max(60, frac.w * vis.width) }
        if r.height < 60 { r.size.height = max(60, frac.h * vis.height) }
        return r
    }
}
