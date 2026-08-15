import Foundation

struct SudokuCell: Identifiable, Codable, Equatable {
    let row: Int
    let col: Int
    var isGiven: Bool = false
    var value: Int?
    var notes: Set<Int> = []
    var isConflict: Bool = false

    var id: Int { row * 9 + col }
    var boxIndex: Int { (row / 3) * 3 + (col / 3) }
}

enum Difficulty: String, CaseIterable, Codable {
    case easy, medium, hard, expert

    var minClues: Int {
        switch self {
        case .easy: return 40
        case .medium: return 32
        case .hard: return 26
        case .expert: return 23
        }
    }

    var maxClues: Int {
        switch self {
        case .easy: return 45
        case .medium: return 36
        case .hard: return 30
        case .expert: return 25
        }
    }

    var maxHints: Int {
        switch self {
        case .easy: return 3
        case .medium: return 4
        case .hard: return 5
        case .expert: return 5
        }
    }
}
