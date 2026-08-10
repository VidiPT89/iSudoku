import Foundation

/// Backtracking solver over a flat 81-int grid (0 = empty). Used at generation time to
/// verify uniqueness of a dug puzzle and to check row/column/box legality; the game itself
/// never re-solves — hints are O(1) lookups against the cached solution grid.
enum SudokuSolver {
    static func isLegal(_ grid: [Int], _ row: Int, _ col: Int, _ digit: Int) -> Bool {
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for i in 0..<9 {
            if grid[row * 9 + i] == digit { return false }
            if grid[i * 9 + col] == digit { return false }
            let br = boxRow + i / 3
            let bc = boxCol + i % 3
            if grid[br * 9 + bc] == digit { return false }
        }
        return true
    }

    /// Minimum-remaining-values heuristic: picks the empty cell with the fewest legal
    /// candidates, so the backtracker fails fast instead of blindly scanning row-major.
    private static func findMrvCell(_ grid: [Int]) -> (index: Int, candidates: [Int])? {
        var best: (index: Int, candidates: [Int])?
        for idx in 0..<81 where grid[idx] == 0 {
            let row = idx / 9, col = idx % 9
            let candidates = (1...9).filter { isLegal(grid, row, col, $0) }
            if candidates.isEmpty { return (idx, []) }
            if best == nil || candidates.count < best!.candidates.count {
                best = (idx, candidates)
                if candidates.count == 1 { break }
            }
        }
        return best
    }

    /// Counts solutions up to `cap`, stopping early once reached — used to verify a dug
    /// puzzle still has exactly one solution without paying for a full enumeration.
    static func countSolutions(_ grid: [Int], cap: Int = 2) -> Int {
        var count = 0
        var working = grid

        func backtrack() -> Bool {
            guard let cell = findMrvCell(working) else {
                count += 1
                return count >= cap
            }
            if cell.candidates.isEmpty { return false }
            let row = cell.index / 9, col = cell.index % 9
            for digit in cell.candidates {
                working[cell.index] = digit
                if backtrack() { return true }
            }
            working[cell.index] = 0
            _ = row; _ = col
            return false
        }

        _ = backtrack()
        return count
    }

    /// Returns the set of cell indices participating in a row/column/box duplicate.
    static func findConflictIndices(_ values: [Int]) -> Set<Int> {
        var conflicts: Set<Int> = []

        for row in 0..<9 {
            var seen: [Int: [Int]] = [:]
            for col in 0..<9 {
                let idx = row * 9 + col
                let v = values[idx]
                if v != 0 { seen[v, default: []].append(idx) }
            }
            for (_, idxs) in seen where idxs.count > 1 { conflicts.formUnion(idxs) }
        }

        for col in 0..<9 {
            var seen: [Int: [Int]] = [:]
            for row in 0..<9 {
                let idx = row * 9 + col
                let v = values[idx]
                if v != 0 { seen[v, default: []].append(idx) }
            }
            for (_, idxs) in seen where idxs.count > 1 { conflicts.formUnion(idxs) }
        }

        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                var seen: [Int: [Int]] = [:]
                for r in boxRow..<(boxRow + 3) {
                    for c in boxCol..<(boxCol + 3) {
                        let idx = r * 9 + c
                        let v = values[idx]
                        if v != 0 { seen[v, default: []].append(idx) }
                    }
                }
                for (_, idxs) in seen where idxs.count > 1 { conflicts.formUnion(idxs) }
            }
        }

        return conflicts
    }
}
