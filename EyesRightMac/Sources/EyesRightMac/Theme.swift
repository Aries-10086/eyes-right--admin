import SwiftUI

/// 流萤印象配色 · 亮色底
enum AppTheme {
    static let fireflyMint = Color(red: 0.49, green: 0.92, blue: 0.84)
    static let fireflyTeal = Color(red: 0.37, green: 0.81, blue: 0.75)
    static let fireflyAmber = Color(red: 1.0, green: 0.72, blue: 0.42)
    static let fireflyPink = Color(red: 0.96, green: 0.78, blue: 0.82)

    static let accent = fireflyTeal
    static let accentDeep = Color(red: 0.28, green: 0.68, blue: 0.62)

    static let canvas = Color(red: 0.99, green: 0.99, blue: 0.98)
    static let panel = Color(red: 0.96, green: 0.98, blue: 0.97)
    static let panelStroke = fireflyTeal.opacity(0.18)
    static let textPrimary = Color(red: 0.12, green: 0.15, blue: 0.18)
    static let muted = Color(red: 0.45, green: 0.50, blue: 0.52)
}
