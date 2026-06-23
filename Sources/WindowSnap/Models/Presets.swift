import Foundation
import Carbon.HIToolbox

/// Built-in fractional rects, command definitions, and layouts.
enum Presets {
    // MARK: - Fractional rects (top-left origin)

    static let leftHalf = FracRect(0, 0, 0.5, 1)
    static let rightHalf = FracRect(0.5, 0, 0.5, 1)
    static let topHalf = FracRect(0, 0, 1, 0.5)
    static let bottomHalf = FracRect(0, 0.5, 1, 0.5)
    static let maximize = FracRect(0, 0, 1, 1)
    static let center = FracRect(0.2, 0.1, 0.6, 0.8)

    static let firstThird = FracRect(0, 0, 1.0 / 3.0, 1)
    static let centerThird = FracRect(1.0 / 3.0, 0, 1.0 / 3.0, 1)
    static let lastThird = FracRect(2.0 / 3.0, 0, 1.0 / 3.0, 1)
    static let firstTwoThirds = FracRect(0, 0, 2.0 / 3.0, 1)
    static let lastTwoThirds = FracRect(1.0 / 3.0, 0, 2.0 / 3.0, 1)

    static let topLeftQ = FracRect(0, 0, 0.5, 0.5)
    static let topRightQ = FracRect(0.5, 0, 0.5, 0.5)
    static let bottomLeftQ = FracRect(0, 0.5, 0.5, 0.5)
    static let bottomRightQ = FracRect(0.5, 0.5, 0.5, 0.5)

    // MARK: - Commands

    private static func key(_ code: Int, _ mods: UInt32) -> HotKeyCombo {
        HotKeyCombo(keyCode: UInt32(code), modifiers: mods)
    }

    /// Control+Option, the default modifier set for snap hotkeys.
    private static let ctrlOpt = UInt32(controlKey) | UInt32(optionKey)

    static let commands: [SnapCommand] = [
        SnapCommand(id: .cycleLeft, title: "Snap Left (cycle ½ · ⅓ · ⅔)",
                    targets: [leftHalf, firstThird, firstTwoThirds],
                    defaultHotkey: key(kVK_LeftArrow, ctrlOpt)),
        SnapCommand(id: .cycleRight, title: "Snap Right (cycle ½ · ⅓ · ⅔)",
                    targets: [rightHalf, lastThird, lastTwoThirds],
                    defaultHotkey: key(kVK_RightArrow, ctrlOpt)),
        SnapCommand(id: .cycleUp, title: "Snap Up (cycle top-half · maximize)",
                    targets: [topHalf, maximize],
                    defaultHotkey: key(kVK_UpArrow, ctrlOpt)),
        SnapCommand(id: .cycleDown, title: "Snap Down (cycle bottom-half · center)",
                    targets: [bottomHalf, center],
                    defaultHotkey: key(kVK_DownArrow, ctrlOpt)),
        SnapCommand(id: .maximize, title: "Maximize",
                    targets: [maximize], defaultHotkey: key(kVK_Return, ctrlOpt)),
        SnapCommand(id: .center, title: "Center",
                    targets: [center], defaultHotkey: key(kVK_ANSI_C, ctrlOpt)),
        SnapCommand(id: .presentation, title: "Presentation Zone (1920×1080, 16:9)",
                    targets: [center], defaultHotkey: key(kVK_ANSI_P, ctrlOpt)),
        SnapCommand(id: .topLeftQuarter, title: "Top-Left Quarter",
                    targets: [topLeftQ], defaultHotkey: key(kVK_ANSI_U, ctrlOpt)),
        SnapCommand(id: .topRightQuarter, title: "Top-Right Quarter",
                    targets: [topRightQ], defaultHotkey: key(kVK_ANSI_I, ctrlOpt)),
        SnapCommand(id: .bottomLeftQuarter, title: "Bottom-Left Quarter",
                    targets: [bottomLeftQ], defaultHotkey: key(kVK_ANSI_J, ctrlOpt)),
        SnapCommand(id: .bottomRightQuarter, title: "Bottom-Right Quarter",
                    targets: [bottomRightQ], defaultHotkey: key(kVK_ANSI_K, ctrlOpt)),
        SnapCommand(id: .leftHalf, title: "Left Half", targets: [leftHalf], defaultHotkey: nil),
        SnapCommand(id: .rightHalf, title: "Right Half", targets: [rightHalf], defaultHotkey: nil),
        SnapCommand(id: .topHalf, title: "Top Half", targets: [topHalf], defaultHotkey: nil),
        SnapCommand(id: .bottomHalf, title: "Bottom Half", targets: [bottomHalf], defaultHotkey: nil),
        SnapCommand(id: .firstThird, title: "First Third", targets: [firstThird], defaultHotkey: nil),
        SnapCommand(id: .centerThird, title: "Center Third", targets: [centerThird], defaultHotkey: nil),
        SnapCommand(id: .lastThird, title: "Last Third", targets: [lastThird], defaultHotkey: nil),
        SnapCommand(id: .firstTwoThirds, title: "First Two-Thirds", targets: [firstTwoThirds], defaultHotkey: nil),
        SnapCommand(id: .lastTwoThirds, title: "Last Two-Thirds", targets: [lastTwoThirds], defaultHotkey: nil),
    ]

    static func command(_ id: CommandID) -> SnapCommand {
        commands.first(where: { $0.id == id })!
    }

    // MARK: - Built-in layouts (stable IDs so the active selection persists)

    private static func uuid(_ s: String) -> UUID { UUID(uuidString: s)! }

    static let builtInLayouts: [Layout] = [
        Layout(id: uuid("00000000-0000-0000-0000-000000000001"), name: "Thirds", zones: [
            Zone(name: "Left", rect: firstThird),
            Zone(name: "Center", rect: centerThird),
            Zone(name: "Right", rect: lastThird),
        ], isBuiltIn: true),
        Layout(id: uuid("00000000-0000-0000-0000-000000000002"), name: "Halves", zones: [
            Zone(name: "Left", rect: leftHalf),
            Zone(name: "Right", rect: rightHalf),
        ], isBuiltIn: true),
        Layout(id: uuid("00000000-0000-0000-0000-000000000003"), name: "2/3 + 1/3", zones: [
            Zone(name: "Main", rect: firstTwoThirds),
            Zone(name: "Side", rect: lastThird),
        ], isBuiltIn: true),
        Layout(id: uuid("00000000-0000-0000-0000-000000000004"), name: "1/3 + 2/3", zones: [
            Zone(name: "Side", rect: firstThird),
            Zone(name: "Main", rect: lastTwoThirds),
        ], isBuiltIn: true),
        Layout(id: uuid("00000000-0000-0000-0000-000000000005"), name: "Quadrants", zones: [
            Zone(name: "Top-Left", rect: topLeftQ),
            Zone(name: "Top-Right", rect: topRightQ),
            Zone(name: "Bottom-Left", rect: bottomLeftQ),
            Zone(name: "Bottom-Right", rect: bottomRightQ),
        ], isBuiltIn: true),
        Layout(id: uuid("00000000-0000-0000-0000-000000000006"), name: "Ultrawide · 4 Columns", zones: [
            Zone(name: "1", rect: FracRect(0, 0, 0.25, 1)),
            Zone(name: "2", rect: FracRect(0.25, 0, 0.25, 1)),
            Zone(name: "3", rect: FracRect(0.5, 0, 0.25, 1)),
            Zone(name: "4", rect: FracRect(0.75, 0, 0.25, 1)),
        ], isBuiltIn: true),
        Layout(id: uuid("00000000-0000-0000-0000-000000000007"), name: "Ultrawide · 25/50/25", zones: [
            Zone(name: "Left", rect: FracRect(0, 0, 0.25, 1)),
            Zone(name: "Center", rect: FracRect(0.25, 0, 0.5, 1)),
            Zone(name: "Right", rect: FracRect(0.75, 0, 0.25, 1)),
        ], isBuiltIn: true),
    ]

    static let defaultActiveLayoutID = builtInLayouts[0].id
}
