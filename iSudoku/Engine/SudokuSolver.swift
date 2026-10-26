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

    /// Counts solutions up to `cap`, stopping early once reached — used to verify a dug
    /// puzzle still has exactly one solution without paying for a full enumeration.
    /// Row/column/box digits are tracked as bitmasks (bit d = digit d) and the search always
    /// branches on the empty cell with the fewest candidates (minimum-remaining-values).
    static func countSolutions(_ grid: [Int], cap: Int = 2) -> Int {
        guard grid.count == 81, grid.allSatisfy({ (0...9).contains($0) }),
              cap > 0, findConflictIndices(grid).isEmpty else { return 0 }
        var rows = [Int](repeating: 0, count: 9)
        var cols = [Int](repeating: 0, count: 9)
        var boxes = [Int](repeating: 0, count: 9)
        var empties: [(r: Int, c: Int, b: Int)] = []
        for idx in 0..<81 {
            let r = idx / 9, c = idx % 9, b = (r / 3) * 3 + c / 3
            if grid[idx] == 0 { empties.append((r, c, b)); continue }
            let bit = 1 << grid[idx]
            rows[r] |= bit; cols[c] |= bit; boxes[b] |= bit
        }

        func search(_ remaining: Int) -> Int {
            if remaining == 0 { return 1 }
            var best = -1, bestMask = 0, bestCount = 10
            for k in 0..<remaining {
                let cell = empties[k]
                let mask = ~(rows[cell.r] | cols[cell.c] | boxes[cell.b]) & 0x3fe
                let n = mask.nonzeroBitCount
                if n == 0 { return 0 }
                if n < bestCount {
                    best = k; bestMask = mask; bestCount = n
                    if n == 1 { break }
                }
            }
            // Move the chosen cell to the end of the active range so the recursion sees the rest.
            empties.swapAt(best, remaining - 1)
            let cell = empties[remaining - 1]
            var found = 0
            var mask = bestMask
            while mask != 0 && found < cap {
                let bit = mask & -mask
                rows[cell.r] |= bit; cols[cell.c] |= bit; boxes[cell.b] |= bit
                found += search(remaining - 1)
                rows[cell.r] &= ~bit; cols[cell.c] &= ~bit; boxes[cell.b] &= ~bit
                mask &= mask - 1
            }
            empties.swapAt(best, remaining - 1)
            return found
        }

        return min(cap, search(empties.count))
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

    // MARK: - Human techniques (singles)

    /// Cell indices of a row, column or 3x3 box (boxes numbered left-to-right, top-to-bottom).
    static func indices(of unit: SudokuUnit) -> [Int] {
        switch unit.kind {
        case .row: return (0..<9).map { unit.index * 9 + $0 }
        case .col: return (0..<9).map { $0 * 9 + unit.index }
        case .box:
            let r0 = (unit.index / 3) * 3, c0 = (unit.index % 3) * 3
            return (0..<9).map { (r0 + $0 / 3) * 9 + c0 + $0 % 3 }
        }
    }

    private static func candidateMasks(_ grid: [Int]) -> [Int] {
        var rows = [Int](repeating: 0, count: 9), cols = rows, boxes = rows
        for idx in 0..<81 where grid[idx] != 0 {
            let bit = 1 << grid[idx], r = idx / 9, c = idx % 9
            rows[r] |= bit; cols[c] |= bit; boxes[(r / 3) * 3 + c / 3] |= bit
        }
        return (0..<81).map { idx in
            guard grid[idx] == 0 else { return 0 }
            let r = idx / 9, c = idx % 9
            return ~(rows[r] | cols[c] | boxes[(r / 3) * 3 + c / 3]) & 0x3fe
        }
    }

    /// Finds one single in a conflict-free grid: a digit with only one possible cell in a box,
    /// row or column (hidden single — boxes first, the easiest to spot), or a cell with only one
    /// possible digit (naked single). `onlyIndex` restricts the search to deductions for that cell.
    static func findSingle(_ grid: [Int], onlyIndex: Int? = nil) -> SingleStep? {
        let masks = candidateMasks(grid)
        for kind in [SudokuUnit.Kind.box, .row, .col] {
            for n in 0..<9 {
                let unit = SudokuUnit(kind: kind, index: n)
                let cells = indices(of: unit)
                if let only = onlyIndex, !cells.contains(only) { continue }
                for digit in 1...9 {
                    let homes = cells.filter { masks[$0] & (1 << digit) != 0 }
                    if homes.count == 1, onlyIndex == nil || homes[0] == onlyIndex {
                        return SingleStep(index: homes[0], digit: digit, technique: .hidden, unit: unit)
                    }
                }
            }
        }
        for idx in 0..<81 where (onlyIndex == nil || idx == onlyIndex) && masks[idx].nonzeroBitCount == 1 {
            return SingleStep(index: idx, digit: masks[idx].trailingZeroBitCount, technique: .naked, unit: nil)
        }
        return nil
    }

    /// True when repeatedly placing singles fills the whole grid. Every placement is forced,
    /// so a grid that passes also has exactly one solution.
    static func solvesWithSingles(_ grid: [Int]) -> Bool {
        var work = grid
        while work.contains(0) {
            let masks = candidateMasks(work)
            if (0..<81).contains(where: { work[$0] == 0 && masks[$0] == 0 }) { return false }
            guard let step = findSingle(work) else { return false }
            work[step.index] = step.digit
        }
        return findConflictIndices(work).isEmpty
    }
}

struct SudokuUnit: Equatable {
    enum Kind { case row, col, box }
    let kind: Kind
    let index: Int
}

/// How a hint filled its cell, so the UI can explain the reasoning.
enum HintTechnique: Equatable {
    case hidden  // the digit has only one possible cell in `unit`
    case naked   // the cell has only one possible digit
    case wrong   // the cell held a wrong digit
    case reveal  // no single applies; the answer is shown
}

struct SingleStep: Equatable {
    let index: Int
    let digit: Int
    let technique: HintTechnique
    let unit: SudokuUnit?
}
