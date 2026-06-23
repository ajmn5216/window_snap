import AppKit
import ApplicationServices

/// Reads and writes window geometry through the Accessibility API.
///
/// All rects here are in **top-left-origin global coordinates** (the same space
/// the AX API uses for `kAXPositionAttribute`).
final class WindowManager {

    // MARK: - Finding windows

    /// The focused window of the frontmost application.
    func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        if let win = copyElement(axApp, kAXFocusedWindowAttribute) { return win }
        if let win = copyElement(axApp, kAXMainWindowAttribute) { return win }

        // Fallback: first standard window.
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement], let first = windows.first {
            return first
        }
        return nil
    }

    /// The window directly under a top-left-origin global point (e.g. the cursor).
    func window(at point: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element)
        guard result == .success, let el = element else { return nil }
        return enclosingWindow(of: el)
    }

    /// Walk up the AX hierarchy until we reach the element whose role is window.
    private func enclosingWindow(of element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var depth = 0
        while let el = current, depth < 12 {
            if role(of: el) == (kAXWindowRole as String) { return el }
            current = copyElement(el, kAXParentAttribute)
            depth += 1
        }
        return nil
    }

    // MARK: - Reading geometry

    func frame(of window: AXUIElement) -> CGRect? {
        guard let position = position(of: window), let size = size(of: window) else { return nil }
        return CGRect(origin: position, size: size)
    }

    func position(of window: AXUIElement) -> CGPoint? {
        guard let value = copyValue(window, kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(value, .cgPoint, &point)
        return point
    }

    func size(of window: AXUIElement) -> CGSize? {
        guard let value = copyValue(window, kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        AXValueGetValue(value, .cgSize, &size)
        return size
    }

    /// The screen a window mostly lives on (by its center point).
    func screen(of window: AXUIElement) -> NSScreen? {
        guard let f = frame(of: window) else { return NSScreen.main }
        return Geometry.screen(containingTopLeft: CGPoint(x: f.midX, y: f.midY)) ?? NSScreen.main
    }

    // MARK: - Writing geometry

    /// Move and resize a window to `frame` (top-left global coords).
    ///
    /// Some apps enforce minimum sizes or ignore the first size change, so we set
    /// size and position twice and then verify, nudging once more if the result
    /// is off by more than a tolerance.
    func setFrame(_ frame: CGRect, for window: AXUIElement) {
        setSize(window, frame.size)
        setPosition(window, frame.origin)
        setSize(window, frame.size)
        setPosition(window, frame.origin)

        guard let actual = self.frame(of: window) else { return }
        let tol: CGFloat = 2
        let off = abs(actual.origin.x - frame.origin.x) > tol
            || abs(actual.origin.y - frame.origin.y) > tol
            || abs(actual.size.width - frame.size.width) > tol
            || abs(actual.size.height - frame.size.height) > tol
        if off {
            // Re-apply once. If the window has a minimum size larger than the
            // target, at least the position will be correct.
            setSize(window, frame.size)
            setPosition(window, frame.origin)
        }
    }

    private func setPosition(_ window: AXUIElement, _ point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private func setSize(_ window: AXUIElement, _ size: CGSize) {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    // MARK: - Low-level AX helpers

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let result = value, CFGetTypeID(result) == AXUIElementGetTypeID()
        else { return nil }
        return (result as! AXUIElement)
    }

    private func copyValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let result = value, CFGetTypeID(result) == AXValueGetTypeID()
        else { return nil }
        return (result as! AXValue)
    }
}
