import SwiftUI

/// ividi.dev-matched dark/amber palette, identical across all Vidi apps, plus Sudoku-specific
/// tokens for cell states (given/user digits, selection, peer highlight, conflicts, notes).
enum Theme {
    static let bg = Color(red: 0x0a / 255.0, green: 0x0a / 255.0, blue: 0x0f / 255.0)
    static let bgPanel = Color(red: 0x0d / 255.0, green: 0x0d / 255.0, blue: 0x18 / 255.0)
    static let bgPanel2 = Color(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x1f / 255.0)
    static let border = Color(red: 226 / 255.0, green: 232 / 255.0, blue: 240 / 255.0).opacity(0.10)
    static let borderStrong = Color(red: 226 / 255.0, green: 232 / 255.0, blue: 240 / 255.0).opacity(0.18)
    static let text = Color(red: 0xe2 / 255.0, green: 0xe8 / 255.0, blue: 0xf0 / 255.0)
    static let textDim = Color(red: 0x94 / 255.0, green: 0xa3 / 255.0, blue: 0xb8 / 255.0)
    static let textFaint = Color(red: 0x5b / 255.0, green: 0x64 / 255.0, blue: 0x74 / 255.0)
    static let accent = Color(red: 0xf9 / 255.0, green: 0x9c / 255.0, blue: 0x00 / 255.0)
    static let accentLight = Color(red: 0xfc / 255.0, green: 0xbb / 255.0, blue: 0x00 / 255.0)
    static let accentDark = Color(red: 0xdd / 255.0, green: 0x74 / 255.0, blue: 0x00 / 255.0)
    static let accentGlow = Color(red: 0xf9 / 255.0, green: 0x9c / 255.0, blue: 0x00 / 255.0).opacity(0.35)
    static let danger = Color(red: 0xef / 255.0, green: 0x44 / 255.0, blue: 0x44 / 255.0)
    static let ok = Color(red: 0x22 / 255.0, green: 0xc5 / 255.0, blue: 0x5e / 255.0)

    // Sudoku-specific
    static let givenDigit = text
    static let userDigit = accentLight
    static let selectedCellBg = accent.opacity(0.20)
    static let peerHighlightBg = accent.opacity(0.09)
    static let sameNumberHighlightBg = accentLight.opacity(0.13)
    static let conflictBg = danger.opacity(0.16)
    static let conflictText = danger
    static let noteText = textFaint

    static let radius: CGFloat = 10
    static let ease: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.35)
}
