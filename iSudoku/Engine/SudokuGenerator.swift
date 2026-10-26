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
    /// a few times and keeps the sparsest puzzle.
    private static let digAttempts = 12

    /// Puzzles with at least this many clues (Easy, Medium and the matching challenge levels)
    /// must stay solvable with singles alone: no guessing, and every hint has a deduction.
    static let singlesOnlyMinClues = 32

    static func generate(_ difficulty: Difficulty, targetClues: Int? = nil) -> GeneratedPuzzle {
        let floor = targetClues ?? difficulty.minClues
        var best = digOnce(towards: floor)
        for _ in 1..<digAttempts where best.clues > floor {
            let dug = digOnce(towards: floor)
            if dug.clues < best.clues { best = dug }
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
        let singlesOnly = floor >= singlesOnlyMinClues

        for idx in order {
            if clues <= floor { break }
            let backup = puzzle[idx]
            puzzle[idx] = 0
            if singlesOnly ? SudokuSolver.solvesWithSingles(puzzle) : SudokuSolver.countSolutions(puzzle, cap: 2) == 1 {
                clues -= 1
            } else {
                puzzle[idx] = backup
            }
        }

        return (GeneratedPuzzle(given: puzzle, solution: solution), clues)
    }
}
