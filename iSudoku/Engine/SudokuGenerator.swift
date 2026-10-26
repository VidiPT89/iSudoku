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

    /// Puzzles are graded by the human techniques they need, so they never require guessing:
    /// `singlesOnlyMinClues`+ clues (Easy, Medium and matching challenge levels) — singles only;
    /// `techniquesMinClues`+ (Hard and matching levels) — plus pointing, claiming and naked pairs;
    /// below that (expert challenge levels) — plus X-Wing.
    static let singlesOnlyMinClues = 32
    static let techniquesMinClues = 26

    /// Technique band for a clue target: the hardest technique allowed and the dig budget spent
    /// looking for a puzzle that really needs it. X-Wing puzzles are rare (a few per hundred
    /// digs), so after `settleAfter` attempts an expert search accepts one that needs the basic
    /// eliminations, which almost every expert level reaches.
    private static func band(for floor: Int) -> (level: TechniqueLevel, attempts: Int, settleAfter: Int) {
        if floor >= singlesOnlyMinClues { return (.singles, 12, 12) }
        if floor >= techniquesMinClues { return (.basic, 40, 40) }
        return (.xWing, 60, 20)
    }

    /// A single dig can get stuck above the target on low clue counts, so `generate` retries and
    /// keeps the best puzzle: first one that reaches the target, then one the simpler technique
    /// levels cannot finish, so Hard asks for eliminations and expert levels for X-Wing when one
    /// turns up.
    static func generate(_ difficulty: Difficulty, targetClues: Int? = nil) -> GeneratedPuzzle {
        let floor = targetClues ?? difficulty.minClues
        let (level, attempts, settleAfter) = band(for: floor)
        // Lower is better: reaching the target matters most, then each simpler level that still
        // finishes the puzzle costs a point.
        func score(_ dug: (puzzle: GeneratedPuzzle, clues: Int)) -> Int {
            var points = dug.clues > floor ? level.rawValue + 1 : 0
            for simpler in 0..<level.rawValue where Techniques.solvesLogically(dug.puzzle.given, level: TechniqueLevel(rawValue: simpler)!) { points += 1 }
            return points
        }
        var best = digOnce(towards: floor, level: level)
        var bestScore = score(best)
        var attempt = 1
        while attempt < attempts && bestScore > 0 && !(attempt >= settleAfter && bestScore <= 1) {
            let dug = digOnce(towards: floor, level: level)
            let dugScore = score(dug)
            if dugScore < bestScore || (dugScore == bestScore && dug.clues < best.clues) { best = dug; bestScore = dugScore }
            attempt += 1
        }
        return best.puzzle
    }

    private static func digOnce(towards floor: Int, level: TechniqueLevel) -> (puzzle: GeneratedPuzzle, clues: Int) {
        var full = [Int](repeating: 0, count: 81)
        _ = fillGrid(&full)
        let solution = full

        var puzzle = full
        var clues = 81
        let order = (0..<81).shuffled()
        for idx in order {
            if clues <= floor { break }
            let backup = puzzle[idx]
            puzzle[idx] = 0
            if Techniques.solvesLogically(puzzle, level: level) {
                clues -= 1
            } else {
                puzzle[idx] = backup
            }
        }

        return (GeneratedPuzzle(given: puzzle, solution: solution), clues)
    }
}
