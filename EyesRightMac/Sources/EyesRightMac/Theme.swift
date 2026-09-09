import SwiftUI

/// B 站印象粉白配色（与 Flutter 移动端对齐）
enum AppTheme {
    static let pink = Color(red: 0.984, green: 0.447, blue: 0.600) // #FB7299
    static let pinkDeep = Color(red: 0.910, green: 0.353, blue: 0.518)
    static let pinkSoft = Color(red: 1.0, green: 0.941, blue: 0.961)
    static let pinkWash = Color(red: 1.0, green: 0.839, blue: 0.906)
    static let blue = Color(red: 0.0, green: 0.631, blue: 0.839) // #00A1D6

    static let accent = pink
    static let accentDeep = pinkDeep

    static let canvas = Color(red: 0.957, green: 0.957, blue: 0.957)
    static let panel = Color.white
    static let panelStroke = Color(red: 0.890, green: 0.898, blue: 0.906)
    static let textPrimary = Color(red: 0.094, green: 0.098, blue: 0.110)
    static let muted = Color(red: 0.580, green: 0.600, blue: 0.627)

    // legacy aliases used by existing views
    static let fireflyMint = pinkSoft
    static let fireflyTeal = pink
    static let fireflyAmber = blue
    static let fireflyPink = pinkWash
}
