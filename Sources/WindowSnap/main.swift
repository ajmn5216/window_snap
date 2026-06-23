import AppKit

// Menu-bar-only app: no Dock icon, no main menu/window. The .app bundle also
// sets LSUIElement=true (see build_app.sh) but .accessory makes it work even
// when run as a bare binary.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
