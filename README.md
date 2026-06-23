# WindowSnap

A native macOS menu-bar app that snaps windows into zones — built for ultrawide
displays. Keyboard-driven snapping with preset cycling, a Shift+drag overlay for
dropping windows into zones, and a visual editor for defining and saving your own
layouts.

- **Menu-bar only** (no Dock icon), Swift + AppKit, Apple Silicon native.
- **Accessibility API** to move/resize windows in other apps.
- **Carbon global hotkeys** (fully remappable, persisted).
- **CGEventTap** for the Shift+drag overlay.
- **JSON persistence** in `~/Library/Application Support/WindowSnap/`.

---

## Requirements

- macOS 13 (Ventura) or later, Apple Silicon.
- Swift toolchain (Xcode or Command Line Tools — `xcode-select --install`).

## Build & run

```bash
cd window_snap
./build_app.sh            # compiles + bundles ./WindowSnap.app (ad-hoc signed)
open WindowSnap.app
```

For day-to-day development you can also just `swift build` and run the binary, but
the `.app` bundle is what enables menu-bar-only behavior (`LSUIElement`) and the
launch-at-login toggle. To open in Xcode (if installed): `File ▸ Open ▸ Package.swift`.

### Grant Accessibility permission (required)

macOS requires explicit permission for any app that controls other apps' windows.
On first launch WindowSnap shows a prompt and a guidance dialog:

1. **System Settings ▸ Privacy & Security ▸ Accessibility**.
2. Enable **WindowSnap**.
3. That's it — WindowSnap detects the grant automatically (it polls every second),
   no restart needed.

> **Re-grant after rebuilds:** `build_app.sh` ad-hoc signs, and ad-hoc identity
> changes whenever the code changes. macOS may therefore drop the permission after
> a rebuild. If snapping stops working, toggle WindowSnap off and back on in that
> Accessibility list. To avoid this entirely, sign with a stable Developer ID.

Carbon hotkeys are registered even before permission is granted, but the actual
window moves (and the Shift+drag overlay) only work once Accessibility is allowed.

---

## Default keybindings

All shortcuts are remappable in **Preferences ▸ Keyboard Shortcuts**. Defaults use
**⌃⌥ (Control+Option)**. Cycling commands step through related presets when you
press the same shortcut again within ~2 seconds.

| Shortcut | Action |
|---|---|
| ⌃⌥ ← | Snap Left — cycles half → first-third → first-two-thirds |
| ⌃⌥ → | Snap Right — cycles half → last-third → last-two-thirds |
| ⌃⌥ ↑ | Snap Up — cycles top-half → maximize |
| ⌃⌥ ↓ | Snap Down — cycles bottom-half → center |
| ⌃⌥ ↩ | Maximize |
| ⌃⌥ C | Center |
| ⌃⌥ P | Presentation Zone (1920×1080, 16:9) |
| ⌃⌥ U / I / J / K | Top-Left / Top-Right / Bottom-Left / Bottom-Right quarter |

More commands (explicit halves, thirds, two-thirds) have no default shortcut but
can be assigned in Preferences and are available from the menu.

To clear a shortcut, click its field in Preferences and press **Delete**.
**Escape** cancels recording.

### Shift + drag to snap

With **Enable Shift + drag overlay snapping** on (default), start dragging any
window and hold **Shift**: the current layout's zones appear as an overlay on the
display under the cursor, the zone under the pointer highlights, and releasing the
mouse snaps the window into it.

### Menu bar

Click the menu-bar icon to see a clickable mini-map of the active layout — click a
zone to snap the focused window into it. The menu also lets you switch layouts, run
any snap command, open the editor, and open Preferences.

---

## Layouts & the zone editor

A **layout** is a named set of **zones**; a zone is a rectangle stored as a
fraction of the display's *visible* area, so it scales to any display and never
overlaps the menu bar or Dock.

**Built-in layouts:** Thirds (default), Halves, 2/3 + 1/3, 1/3 + 2/3, Quadrants,
Ultrawide · 4 Columns, Ultrawide · 25/50/25.

**Edit Zones…** (menu or ⌘E in the menu) opens the editor:

- **Layout** popup — pick any built-in or custom layout to edit. Editing a
  built-in and saving creates a *custom copy* (built-ins are never overwritten).
- **New / Duplicate / Delete** — manage custom layouts.
- **Name** — rename the layout.
- **Generate Grid** — enter columns × rows to auto-fill an even grid.
- **Add Zone / Delete Zone / Rename Zone** — manage individual zones.
- On the canvas: **drag** a zone to move it, **drag its corners** to resize.
  Everything snaps to a grid (1/24 increments).
- **Save** stores the layout; **Save & Activate** also makes it the active layout
  used by hotkey zone-snaps, the menu grid, and the Shift+drag overlay.

### Other preferences

- **Gap** between zones (and from screen edges), 0–30 px.
- **Launch at login** (via `SMAppService`).
- **Enable Shift + drag overlay snapping** toggle.

Everything is saved to `~/Library/Application Support/WindowSnap/config.json`
(built-in layouts are regenerated at launch and not stored there).

---

## Architecture

```
Sources/WindowSnap/
  main.swift                 NSApplication bootstrap (.accessory activation policy)
  AppDelegate.swift          Wiring: status item, hotkeys, drag monitor, permission flow
  AppState.swift             Settings + layouts, persistence, change notifications (singleton)
  SnapEngine.swift           Fraction→pixels, preset cycling, presentation zone
  Models/
    Geometry.swift           FracRect + Cocoa↔top-left coordinate conversions
    Zone.swift               Zone, Layout
    Command.swift            CommandID, SnapCommand
    Settings.swift           Settings, HotKeyCombo
    Presets.swift            Built-in rects, commands (+ default hotkeys), layouts
  Persistence/Store.swift    JSON config in Application Support
  Accessibility/
    AccessibilityPermissions.swift   Trust check + System Settings deep-link
    WindowManager.swift              AX read/set position+size, verify-and-nudge
  Hotkeys/
    HotKeyManager.swift      Carbon RegisterEventHotKey wrapper
    KeyCodes.swift           Key code names + AppKit→Carbon modifier mapping
  Overlay/
    OverlayController.swift   Click-through transparent zone overlay window/view
    DragMonitor.swift         CGEventTap: Shift+drag detection and snap-on-release
  MenuBar/
    StatusItemController.swift  NSStatusItem + menu (built on open)
    GridMenuView.swift          Clickable layout mini-map in the menu
  Preferences/
    PreferencesWindowController.swift  Gap, login, drag toggle, hotkey list
    HotkeyRecorderView.swift           Click-to-record hotkey field
  Editor/
    ZoneEditorWindowController.swift   Layout/zone management + save
    ZoneCanvasView.swift               Drag/resize zone canvas with grid snapping
  Util/LaunchAtLogin.swift   SMAppService login-item toggle
```

### Coordinate handling (the macOS gotcha)

macOS exposes two coordinate spaces. **Cocoa** (`NSScreen`, `NSWindow`) uses a
bottom-left origin with y increasing upward; **Accessibility/Quartz**
(`AXUIElement`, `CGEvent`) uses a top-left origin with y increasing downward. Zones
are computed from `NSScreen.visibleFrame` (which already excludes the menu bar and
Dock) and converted to top-left coordinates in `Geometry` before driving the AX
API. Zones are stored as fractional rects per display so they scale to the
ultrawide's large pixel dimensions and to any monitor.

### Apps that resist resizing

Some windows enforce a minimum size or ignore the first size change. `WindowManager`
sets size and position twice, then reads the result back and nudges once more if the
window landed more than 2 px off target.

### Reference

The Accessibility move/resize approach, multi-monitor handling, and snap-area
overlay are modeled on patterns from the open-source app
[Rectangle](https://github.com/rxhanson/Rectangle) (MIT). Patterns were borrowed,
not code.

### Notable deviations from the suggested stack

- **Swift Package + `build_app.sh`** instead of a checked-in `.xcodeproj`. It builds
  with just Command Line Tools, opens in Xcode via `Package.swift`, and the script
  produces a correct `LSUIElement` bundle. No capability is lost.
- **Carbon `RegisterEventHotKey` directly** rather than the `soffes/HotKey` wrapper,
  to keep the build dependency-free and offline. It's a thin wrapper either way.

---

## Screen sharing

**Phase 1 (now): window positioning only.** To share a single app window into
Teams / Meet / Zoom, use those apps' built-in **"Share a window"** picker — they
handle the capture. WindowSnap's contribution is the **Presentation Zone** preset
(⌃⌥P), which sizes the window you're about to share to a clean **1920×1080, 16:9**
region first, so the shared output looks right.

**Not supported (and why):** sharing an *arbitrary screen region* that isn't tied
to a single window is **not** something macOS or those meeting apps offer natively.
Doing it would require capturing a region and presenting it as a shareable source —
e.g. **ScreenCaptureKit** to grab the region plus a **virtual camera / virtual
display** to expose it to the meeting app. That is a substantial, separate effort
(camera extension entitlements, a system extension, etc.) and is explicitly scoped
as a **future phase**, not part of this app.

---

## License

Released under the [MIT License](LICENSE) — free to use, modify, and
redistribute, with no warranty.

This project borrows design *patterns* (not code) from
[Rectangle](https://github.com/rxhanson/Rectangle), which is also MIT licensed.
See the [Reference](#reference) note above.
