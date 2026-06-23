import Foundation

/// Identifiers for every snap command the app can perform via hotkey or menu.
/// `cycle*` commands step through several targets when the same hotkey is pressed
/// repeatedly (e.g. left-half → left-third → left-two-thirds).
enum CommandID: String, CaseIterable, Codable {
    case cycleLeft, cycleRight, cycleUp, cycleDown
    case maximize, center, presentation
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case firstThird, centerThird, lastThird
    case firstTwoThirds, lastTwoThirds
}

/// Definition of a snap command: an ordered list of fractional targets to cycle
/// through, plus an optional default hotkey.
struct SnapCommand {
    let id: CommandID
    let title: String
    let targets: [FracRect]
    let defaultHotkey: HotKeyCombo?
}
