import Foundation

struct GeneratedPuzzle {
    let given: [Int]
    let solution: [Int]
}

enum SudokuGenerator {
    /// Fills an empty 9x9 grid via randomized backtracking. Shuffling the digit order at
    /// each cell (rather than always trying 1-9 in order) means a fresh full grid every
    /// call, which is what makes each generated puzzle different.
    private static func fillGrid(_ grid: inout [Int]) -> Bool {
        guard let idx = grid.firstIndex(of: 0) else { return true }
        let row = idx / 9, col = idx % 9
        for digit in (1...9).shuffled() {
            if SudokuSolver.isLegal(grid, row, col, digit) {
                grid[idx] = digit
                if fillGrid(&grid) { return true }
                grid[idx] = 0
            }
        }
        return false
    }

    /// A single dig can get stuck above the target on low clue counts, so `generate` retries
    /// and keeps the best puzzle. In the techniques band it also prefers a puzzle that singles
    /// alone cannot finish, so Hard really asks for the elimination techniques.
    private static let digAttempts = 12
    private static let digAttemptsForEliminations = 40

    /// Puzzles are graded by the human techniques they need, so they never require guessing:
    /// `singlesOnlyMinClues`+ clues (Easy, Medium and matching challenge levels) — singles only;
    /// `techniquesMinClues`+ (Hard and matching levels) — singles plus pointing, claiming and
    /// naked pairs; below that (expert challenge levels) — any unique puzzle.
    static let singlesOnlyMinClues = 32
    static let techniquesMinClues = 26

    static func generate(_ difficulty: Difficulty, targetClues: Int? = nil) -> GeneratedPuzzle {
        let floor = targetClues ?? difficulty.minClues
        let wantsEliminations = (techniquesMinClues..<singlesOnlyMinClues).contains(floor)
        func score(_ dug: (puzzle: GeneratedPuzzle, clues: Int)) -> Int {
            (dug.clues > floor ? 2 : 0) + (wantsEliminations && Techniques.solvesLogically(dug.puzzle.given) ? 1 : 0)
        }
        var best = digOnce(towards: floor)
        var bestScore = score(best)
        for _ in 1..<(wantsEliminations ? digAttemptsForEliminations : digAttempts) where bestScore > 0 {
            let dug = digOnce(towards: floor)
            let dugScore = score(dug)
            if dugScore < bestScore || (dugScore == bestScore && dug.clues < best.clues) { best = dug; bestScore = dugScore }
        }
        return best.puzzle
    }

    private static func digOnce(towards floor: Int) -> (puzzle: GeneratedPuzzle, clues: Int) {
        var full = [Int](repeating: 0, count: 81)
        _ = fillGrid(&full)
        let solution = full

        var puzzle = full
        var clues = 81
        let order = (0..<81).shuffled()
        let keepsUnique: ([Int]) -> Bool = floor >= singlesOnlyMinClues ? { Techniques.solvesLogically($0) }
            : floor >= techniquesMinClues ? { Techniques.solvesLogically($0, withEliminations: true) }
            : { SudokuSolver.countSolutions($0, cap: 2) == 1 }

        for idx in order {
            if clues <= floor { break }
            let backup = puzzle[idx]
            puzzle[idx] = 0
            if keepsUnique(puzzle) {
                clues -= 1
            } else {
                puzzle[idx] = backup
            }
        }

        return (GeneratedPuzzle(given: puzzle, solution: solution), clues)
    }
}
