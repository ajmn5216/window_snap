import Foundation
import Carbon.HIToolbox

/// A registered global hotkey, stored as a raw key code plus a Carbon modifier
/// mask so it round-trips cleanly to JSON and to `RegisterEventHotKey`.
struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon mask: cmdKey | optionKey | controlKey | shiftKey

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += KeyCodes.name(for: keyCode)
        return s
    }
}

/// User-tunable preferences. `hotkeys` holds per-command overrides keyed by
/// `CommandID.rawValue`; commands without an override fall back to their default.
struct Settings: Codable {
    var gap: Double = 8
    var launchAtLogin: Bool = false
    var activeLayoutID: UUID? = nil
    var shiftDragEnabled: Bool = true
    var hotkeys: [String: HotKeyCombo] = [:]

    enum CodingKeys: String, CodingKey {
        case gap, launchAtLogin, activeLayoutID, shiftDragEnabled, hotkeys
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gap = try c.decodeIfPresent(Double.self, forKey: .gap) ?? 8
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        activeLayoutID = try c.decodeIfPresent(UUID.self, forKey: .activeLayoutID)
        shiftDragEnabled = try c.decodeIfPresent(Bool.self, forKey: .shiftDragEnabled) ?? true
        hotkeys = try c.decodeIfPresent([String: HotKeyCombo].self, forKey: .hotkeys) ?? [:]
    }
}
