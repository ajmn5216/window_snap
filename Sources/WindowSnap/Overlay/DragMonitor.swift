import AppKit
import ApplicationServices

/// Watches global mouse events via a `CGEventTap`. When the user drags a window
/// with Shift held, it shows the zone overlay and snaps the dragged window into
/// the highlighted zone on mouse-up.
///
/// Requires Accessibility permission (the tap is created listen-only and never
/// modifies events).
final class DragMonitor {
    private let overlay = OverlayController()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var dragging = false
    private var draggedWindow: AXUIElement?
    private var currentScreen: NSScreen?
    private var highlightIndex: Int?

    private var wm: WindowManager { AppState.shared.windowManager }
    private var engine: SnapEngine { AppState.shared.snapEngine }

    /// Start (or restart) the event tap. Safe to call once permission is granted.
    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            NSLog("WindowSnap: could not create event tap (Accessibility not granted?)")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        eventTap = nil
        runLoopSource = nil
        cancel()
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard AppState.shared.settings.shiftDragEnabled else { return }

        let shiftHeld = event.flags.contains(.maskShift)
        let location = event.location // global, top-left origin

        switch type {
        case .leftMouseDown:
            if shiftHeld {
                draggedWindow = wm.window(at: location)
            }

        case .leftMouseDragged:
            guard shiftHeld, draggedWindow != nil else {
                if dragging { cancel() }
                return
            }
            beginOrUpdate(at: location)

        case .leftMouseUp:
            if dragging { commit() }
            draggedWindow = nil

        default:
            break
        }
    }

    private func beginOrUpdate(at location: CGPoint) {
        dragging = true
        guard let screen = Geometry.screen(containingTopLeft: location) else { return }
        let zones = AppState.shared.activeLayout.zones
        let gap = CGFloat(AppState.shared.settings.gap)

        highlightIndex = zones.firstIndex { zone in
            Geometry.absoluteRect(for: zone.rect, on: screen, gap: gap).contains(location)
        }

        if currentScreen != screen {
            currentScreen = screen
            overlay.show(on: screen, zones: zones, gap: gap, highlight: highlightIndex)
        } else {
            overlay.updateHighlight(highlightIndex)
        }
    }

    private func commit() {
        defer { cancel() }
        guard let window = draggedWindow,
              let screen = currentScreen,
              let index = highlightIndex else { return }
        let zones = AppState.shared.activeLayout.zones
        guard index < zones.count else { return }
        engine.snap(toZone: zones[index].rect, window: window, on: screen)
    }

    private func cancel() {
        dragging = false
        currentScreen = nil
        highlightIndex = nil
        overlay.hide()
    }
}
