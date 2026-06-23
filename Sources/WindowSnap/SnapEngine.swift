import AppKit
import ApplicationServices

/// Turns commands and zones into concrete window moves. Owns the cycling state
/// for `cycle*` commands.
final class SnapEngine {
    private let wm: WindowManager

    private var lastCommand: CommandID?
    private var lastCycleIndex = 0
    private var lastFireTime: Date = .distantPast
    private let cycleTimeout: TimeInterval = 2.0

    init(windowManager: WindowManager) {
        self.wm = windowManager
    }

    private var gap: CGFloat { CGFloat(AppState.shared.settings.gap) }

    // MARK: - Commands (hotkeys / preset menu)

    func run(_ id: CommandID, window explicitWindow: AXUIElement? = nil) {
        guard let window = explicitWindow ?? wm.focusedWindow() else { NSSound.beep(); return }
        let screen = wm.screen(of: window) ?? NSScreen.main
        guard let screen else { NSSound.beep(); return }

        if id == .presentation {
            snapPresentation(window, on: screen)
            return
        }

        let targets = Presets.command(id).targets
        let index = nextCycleIndex(for: id, count: targets.count)
        let rect = Geometry.absoluteRect(for: targets[index], on: screen, gap: gap)
        wm.setFrame(rect, for: window)
    }

    private func nextCycleIndex(for id: CommandID, count: Int) -> Int {
        let now = Date()
        if id == lastCommand, now.timeIntervalSince(lastFireTime) < cycleTimeout {
            lastCycleIndex = (lastCycleIndex + 1) % count
        } else {
            lastCycleIndex = 0
        }
        lastCommand = id
        lastFireTime = now
        return lastCycleIndex
    }

    // MARK: - Zones (menu grid / overlay)

    /// Snap the focused window to a zone. Pass an explicit window/screen to avoid
    /// focus ambiguity (e.g. from the status menu or a drag).
    func snap(toZone rect: FracRect, window: AXUIElement? = nil, on screen: NSScreen? = nil) {
        guard let win = window ?? wm.focusedWindow() else { NSSound.beep(); return }
        let scr = screen ?? wm.screen(of: win) ?? NSScreen.main
        guard let scr else { NSSound.beep(); return }
        let pixels = Geometry.absoluteRect(for: rect, on: scr, gap: gap)
        wm.setFrame(pixels, for: win)
    }

    // MARK: - Presentation zone (exact 1920×1080, 16:9)

    private func snapPresentation(_ window: AXUIElement, on screen: NSScreen) {
        let vis = Geometry.topLeft(from: screen.visibleFrame)
        var width: CGFloat = min(1920, vis.width)
        var height: CGFloat = min(1080, vis.height)
        // Preserve a clean 16:9 ratio if either dimension had to be clamped.
        let aspect: CGFloat = 16.0 / 9.0
        if width / height > aspect {
            width = height * aspect
        } else {
            height = width / aspect
        }
        let x = vis.minX + (vis.width - width) / 2
        let y = vis.minY + (vis.height - height) / 2
        wm.setFrame(CGRect(x: x, y: y, width: width, height: height), for: window)
    }
}
