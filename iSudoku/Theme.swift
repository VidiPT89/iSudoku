import SwiftUI

/// Graphite and muted amber, shared with SudokuWeb. Semantic tokens keep
/// selection, candidates and conflicts distinct from decorative surfaces.
enum Theme {
    static let bg = Color(red: 20 / 255.0, green: 23 / 255.0, blue: 22 / 255.0)
    static let bgPanel = Color(red: 25 / 255.0, green: 29 / 255.0, blue: 27 / 255.0)
    static let bgPanel2 = Color(red: 32 / 255.0, green: 38 / 255.0, blue: 34 / 255.0)
    static let border = Color(red: 226 / 255.0, green: 232 / 255.0, blue: 240 / 255.0).opacity(0.14)
    static let borderStrong = Color(red: 226 / 255.0, green: 232 / 255.0, blue: 240 / 255.0).opacity(0.38)
    static let text = Color(red: 240 / 255.0, green: 241 / 255.0, blue: 233 / 255.0)
    static let textDim = Color(red: 180 / 255.0, green: 188 / 255.0, blue: 179 / 255.0)
    static let textFaint = Color(red: 141 / 255.0, green: 153 / 255.0, blue: 143 / 255.0)
    static let accent = Color(red: 232 / 255.0, green: 184 / 255.0, blue: 109 / 255.0)
    static let accentLight = Color(red: 245 / 255.0, green: 206 / 255.0, blue: 144 / 255.0)
    static let accentDark = Color(red: 201 / 255.0, green: 149 / 255.0, blue: 72 / 255.0)
    static let accentGlow = Color(red: 0xf9 / 255.0, green: 0x9c / 255.0, blue: 0x00 / 255.0).opacity(0.12)
    static let danger = Color(red: 255 / 255.0, green: 140 / 255.0, blue: 135 / 255.0)
    static let ok = Color(red: 0x22 / 255.0, green: 0xc5 / 255.0, blue: 0x5e / 255.0)

    // Sudoku-specific
    static let givenDigit = text
    static let userDigit = accentLight
    static let selectedCellBg = Color(red: 85 / 255.0, green: 71 / 255.0, blue: 47 / 255.0)
    static let peerHighlightBg = Color(red: 40 / 255.0, green: 51 / 255.0, blue: 43 / 255.0)
    static let sameNumberHighlightBg = Color(red: 65 / 255.0, green: 67 / 255.0, blue: 50 / 255.0)
    static let conflictBg = Color(red: 73 / 255.0, green: 46 / 255.0, blue: 43 / 255.0)
    static let conflictText = danger
    static let noteText = textDim

    static let radius: CGFloat = 10
    static let ease: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.35)
}
