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

    static func generate(_ difficulty: Difficulty, targetClues: Int? = nil) -> GeneratedPuzzle {
        var full = [Int](repeating: 0, count: 81)
        _ = fillGrid(&full)
        let solution = full

        var puzzle = full
        var clues = 81
        let order = (0..<81).shuffled()
        let floor = targetClues ?? difficulty.minClues

        for idx in order {
            if clues <= floor { break }
            let backup = puzzle[idx]
            puzzle[idx] = 0
            let solutions = SudokuSolver.countSolutions(puzzle, cap: 2)
            if solutions == 1 {
                clues -= 1
            } else {
                puzzle[idx] = backup
            }
        }

        return GeneratedPuzzle(given: puzzle, solution: solution)
    }
}
