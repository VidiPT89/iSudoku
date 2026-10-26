import Foundation

/// Human solving techniques over a candidate grid, used to explain hints and to grade puzzles:
/// - singles: a digit with one possible cell in a box/row/column (hidden), or a cell with one
///   possible digit (naked);
/// - eliminations: pointing (a box's candidates for a digit sit on one line), claiming (a line's
///   candidates for a digit sit in one box), naked pairs and, the hardest, X-Wing (in two rows a
///   digit fits only in the same two columns, or the transpose).
/// Candidates are 9-bit masks (bit d = digit d); filled cells have mask 0.
enum Techniques {
    private static let boxOrder: [SudokuUnit.Kind] = [.box, .row, .col]
    private static let rowOf = (0..<81).map { $0 / 9 }
    private static let colOf = (0..<81).map { $0 % 9 }
    private static let boxOfCell = (0..<81).map(boxOf)
    private static let peers: [[Int]] = (0..<81).map { idx in
        let units = [SudokuUnit(kind: .row, index: idx / 9), SudokuUnit(kind: .col, index: idx % 9), SudokuUnit(kind: .box, index: boxOf(idx))]
        return Array(Set(units.flatMap(\.cells)).subtracting([idx])).sorted()
    }

    static func boxOf(_ idx: Int) -> Int { (idx / 27) * 3 + (idx % 9) / 3 }

    static func candidateMasks(_ grid: [Int]) -> [Int] {
        var rows = [Int](repeating: 0, count: 9), cols = rows, boxes = rows
        for idx in 0..<81 where grid[idx] != 0 {
            let bit = 1 << grid[idx]
            rows[rowOf[idx]] |= bit; cols[colOf[idx]] |= bit; boxes[boxOfCell[idx]] |= bit
        }
        var masks = [Int](repeating: 0, count: 81)
        for idx in 0..<81 where grid[idx] == 0 {
            masks[idx] = ~(rows[rowOf[idx]] | cols[colOf[idx]] | boxes[boxOfCell[idx]]) & 0x3fe
        }
        return masks
    }

    static func digits(of mask: Int) -> [Int] { (1...9).filter { mask & (1 << $0) != 0 } }

    /// One single on the given candidates (boxes first — the easiest to spot), or nil.
    /// `onlyIndex` restricts the search to deductions that fill that cell.
    static func findSingle(in masks: [Int], onlyIndex: Int? = nil) -> SingleStep? {
        for kind in boxOrder {
            for n in 0..<9 {
                let cells = SudokuUnit.table[kind]![n]
                if let only = onlyIndex, !cells.contains(only) { continue }
                // Digits seen in exactly one cell of the unit: once & ~twice.
                var once = 0, twice = 0
                for i in cells { twice |= once & masks[i]; once |= masks[i] }
                var unique = once & ~twice
                if let only = onlyIndex { unique &= masks[only] }
                guard unique != 0 else { continue }
                let digit = unique.trailingZeroBitCount
                guard let index = cells.first(where: { masks[$0] & (1 << digit) != 0 }) else { continue }
                return SingleStep(index: index, digit: digit, technique: .hidden, unit: SudokuUnit(kind: kind, index: n))
            }
        }
        for idx in 0..<81 where (onlyIndex == nil || idx == onlyIndex) && masks[idx].nonzeroBitCount == 1 {
            return SingleStep(index: idx, digit: masks[idx].trailingZeroBitCount, technique: .naked, unit: nil)
        }
        return nil
    }

    static func findSingle(_ grid: [Int], onlyIndex: Int? = nil) -> SingleStep? {
        findSingle(in: candidateMasks(grid), onlyIndex: onlyIndex)
    }

    /// First elimination up to `level` that removes at least one candidate, simplest first.
    static func findElimination(_ masks: [Int], level: TechniqueLevel = .xWing) -> Elimination? {
        // Pointing: a box's candidates for a digit all sit on one row or column.
        for b in 0..<9 {
            let box = SudokuUnit.table[.box]![b]
            for d in 1...9 {
                let bit = 1 << d
                var rowsSeen = 0, colsSeen = 0, count = 0
                for i in box where masks[i] & bit != 0 { rowsSeen |= 1 << rowOf[i]; colsSeen |= 1 << colOf[i]; count += 1 }
                guard count >= 2 else { continue }
                for (kind, seen) in [(SudokuUnit.Kind.row, rowsSeen), (.col, colsSeen)] where seen & (seen - 1) == 0 {
                    let line = SudokuUnit(kind: kind, index: seen.trailingZeroBitCount)
                    let cut = line.cells.filter { boxOfCell[$0] != b && masks[$0] & bit != 0 }.map { Elimination.Removal(index: $0, bits: bit) }
                    if !cut.isEmpty {
                        return Elimination(kind: .pointing, digits: [d], source: SudokuUnit(kind: .box, index: b), target: line,
                                           cells: box.filter { masks[$0] & bit != 0 }, removals: cut)
                    }
                }
            }
        }
        // Claiming: a row's or column's candidates for a digit all sit in one box.
        for kind in [SudokuUnit.Kind.row, .col] {
            let lineOf = kind == .row ? rowOf : colOf
            for n in 0..<9 {
                let line = SudokuUnit.table[kind]![n]
                for d in 1...9 {
                    let bit = 1 << d
                    var boxesSeen = 0, count = 0
                    for i in line where masks[i] & bit != 0 { boxesSeen |= 1 << boxOfCell[i]; count += 1 }
                    guard count >= 2, boxesSeen & (boxesSeen - 1) == 0 else { continue }
                    let box = SudokuUnit(kind: .box, index: boxesSeen.trailingZeroBitCount)
                    let cut = box.cells.filter { lineOf[$0] != n && masks[$0] & bit != 0 }.map { Elimination.Removal(index: $0, bits: bit) }
                    if !cut.isEmpty {
                        return Elimination(kind: .claiming, digits: [d], source: SudokuUnit(kind: kind, index: n), target: box,
                                           cells: line.filter { masks[$0] & bit != 0 }, removals: cut)
                    }
                }
            }
        }
        // Naked pair: two cells of a unit with the same two candidates.
        for kind in boxOrder {
            for n in 0..<9 {
                let cells = SudokuUnit.table[kind]![n]
                for a in 0..<9 where masks[cells[a]].nonzeroBitCount == 2 {
                    let pairMask = masks[cells[a]]
                    for b in (a + 1)..<9 where masks[cells[b]] == pairMask {
                        let cut = cells.filter { $0 != cells[a] && $0 != cells[b] && masks[$0] & pairMask != 0 }
                            .map { Elimination.Removal(index: $0, bits: masks[$0] & pairMask) }
                        if !cut.isEmpty {
                            let unit = SudokuUnit(kind: kind, index: n)
                            return Elimination(kind: .pair, digits: digits(of: pairMask), source: unit, target: unit, cells: [cells[a], cells[b]], removals: cut)
                        }
                    }
                }
            }
        }
        return level >= .xWing ? findXWing(masks) : nil
    }

    /// X-Wing: in two base lines a digit fits only on the same two cover lines, so it leaves the
    /// rest of those cover lines.
    private static func findXWing(_ masks: [Int]) -> Elimination? {
        for (baseKind, coverKind) in [(SudokuUnit.Kind.row, SudokuUnit.Kind.col), (.col, .row)] {
            let lines = SudokuUnit.table[baseKind]!
            for d in 1...9 {
                let bit = 1 << d
                // positions[line] = 9-bit mask of the cover lines where the digit can sit.
                let positions = lines.map { cells in cells.indices.reduce(0) { masks[cells[$1]] & bit != 0 ? $0 | (1 << $1) : $0 } }
                for a in 0..<9 where positions[a].nonzeroBitCount == 2 {
                    for b in (a + 1)..<9 where positions[b] == positions[a] {
                        let cover = (0..<9).filter { positions[a] & (1 << $0) != 0 }
                        let cells = [a, b].flatMap { line in cover.map { lines[line][$0] } }
                        let cut = cover.flatMap { SudokuUnit.table[coverKind]![$0] }
                            .filter { !cells.contains($0) && masks[$0] & bit != 0 }
                            .map { Elimination.Removal(index: $0, bits: bit) }
                        if !cut.isEmpty {
                            return Elimination(kind: .xWing, digits: [d], source: SudokuUnit(kind: baseKind, index: a),
                                               target: SudokuUnit(kind: coverKind, index: cover[0]), cells: cells, removals: cut,
                                               base: [a, b], cover: cover)
                        }
                    }
                }
            }
        }
        return nil
    }

    static func apply(_ elimination: Elimination, to masks: inout [Int]) {
        for removal in elimination.removals { masks[removal.index] &= ~removal.bits }
    }

    /// Re-checks an elimination's reason on the current candidates and applies it; false if the
    /// reason no longer holds (it depended on an elimination that was dropped).
    private static func replay(_ e: Elimination, on masks: inout [Int]) -> Bool {
        let bits = e.digits.reduce(0) { $0 | (1 << $1) }
        if e.kind == .xWing {
            // Each base line must still hold the digit, and only on the cover lines.
            let coverCells = e.cover.flatMap { SudokuUnit(kind: e.target.kind, index: $0).cells }
            let baseLines = e.base.map { SudokuUnit(kind: e.source.kind, index: $0).cells }
            guard baseLines.allSatisfy({ $0.contains { masks[$0] & bits != 0 } }),
                  baseLines.joined().allSatisfy({ masks[$0] & bits == 0 || coverCells.contains($0) }) else { return false }
            let baseCells = Set(baseLines.joined())
            for i in coverCells where !baseCells.contains(i) { masks[i] &= ~bits }
            return true
        }
        let source = e.source.cells, target = e.target.cells
        if e.kind == .pair {
            guard e.cells.allSatisfy({ masks[$0] != 0 && masks[$0] & ~bits == 0 }) else { return false }
            for i in target where !e.cells.contains(i) { masks[i] &= ~bits }
            return true
        }
        let homes = source.filter { masks[$0] & bits != 0 }
        guard homes.count >= 2, homes.allSatisfy(target.contains) else { return false }
        for i in target where !source.contains(i) { masks[i] &= ~bits }
        return true
    }

    private static func replay(_ chain: [Elimination], on grid: [Int]) -> [Int]? {
        var masks = candidateMasks(grid)
        for e in chain { guard replay(e, on: &masks) else { return nil } }
        return masks
    }

    /// A short chain of eliminations (greedy, at most `maxEliminations`) that exposes a single,
    /// optionally for one cell, pruned to the steps the single actually needs.
    static func planDeduction(_ grid: [Int], onlyIndex: Int? = nil, maxEliminations: Int = 30) -> (single: SingleStep, eliminations: [Elimination])? {
        var masks = candidateMasks(grid)
        var eliminations: [Elimination] = []
        var found = findSingle(in: masks, onlyIndex: onlyIndex)
        while found == nil {
            guard eliminations.count < maxEliminations, let elimination = findElimination(masks) else { return nil }
            apply(elimination, to: &masks)
            eliminations.append(elimination)
            found = findSingle(in: masks, onlyIndex: onlyIndex)
        }
        guard var single = found else { return nil }
        for i in stride(from: eliminations.count - 1, through: 0, by: -1) where eliminations.count > 1 {
            var trial = eliminations
            trial.remove(at: i)
            if let trialMasks = replay(trial, on: grid),
               findSingle(in: trialMasks, onlyIndex: single.index)?.digit == single.digit { eliminations = trial }
        }
        if !eliminations.isEmpty, let finalMasks = replay(eliminations, on: grid),
           let step = findSingle(in: finalMasks, onlyIndex: single.index) { single = step }
        return (single, eliminations)
    }

    /// True when the grid can be completed by forced steps only, using techniques up to `level`.
    /// Every step is forced, so a grid that passes also has exactly one solution.
    static func solvesLogically(_ grid: [Int], level: TechniqueLevel = .singles) -> Bool {
        var work = grid
        var masks = candidateMasks(work)
        var empty = work.filter { $0 == 0 }.count
        while empty > 0 {
            if let single = findSingle(in: masks) {
                work[single.index] = single.digit
                masks[single.index] = 0
                empty -= 1
                let clear = ~(1 << single.digit)
                for p in peers[single.index] {
                    masks[p] &= clear
                    if work[p] == 0 && masks[p] == 0 { return false } // contradiction
                }
                continue
            }
            guard level > .singles, let elimination = findElimination(masks, level: level) else { return false }
            apply(elimination, to: &masks)
        }
        return SudokuSolver.findConflictIndices(work).isEmpty
    }
}

/// Technique levels grade puzzles: singles < basic eliminations (pointing, claiming, pairs) < X-Wing.
enum TechniqueLevel: Int, Comparable {
    case singles, basic, xWing
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

struct SudokuUnit: Equatable {
    enum Kind { case row, col, box }
    let kind: Kind
    let index: Int

    /// Cell indices of every unit (boxes numbered left-to-right, top-to-bottom), built once.
    static let table: [Kind: [[Int]]] = [
        .row: (0..<9).map { r in (0..<9).map { r * 9 + $0 } },
        .col: (0..<9).map { c in (0..<9).map { $0 * 9 + c } },
        .box: (0..<9).map { b in (0..<9).map { ((b / 3) * 3 + $0 / 3) * 9 + (b % 3) * 3 + $0 % 3 } },
    ]

    var cells: [Int] { Self.table[kind]![index] }
}

/// How a hint fills its cell, so the UI can explain the reasoning.
enum HintTechnique: Equatable {
    case hidden  // the digit has only one possible cell in `unit`
    case naked   // the cell has only one possible digit
    case wrong   // the cell holds a wrong digit
    case reveal  // no deduction applies; the answer is shown
}

struct SingleStep: Equatable {
    let index: Int
    let digit: Int
    let technique: HintTechnique
    let unit: SudokuUnit?
}

struct Elimination: Equatable {
    enum Kind { case pointing, claiming, pair, xWing }
    struct Removal: Equatable {
        let index: Int
        let bits: Int
    }
    let kind: Kind
    let digits: [Int]
    let source: SudokuUnit
    let target: SudokuUnit
    let cells: [Int]
    let removals: [Removal]
    /// X-Wing only: the two base lines (of `source.kind`) and the two cover lines (of `target.kind`).
    var base: [Int] = []
    var cover: [Int] = []
}

/// A planned hint: shown first as a clue (`revealed == false`), then filled in.
struct HintPlan: Equatable {
    let index: Int
    let digit: Int
    let technique: HintTechnique
    let unit: SudokuUnit?
    let eliminations: [Elimination]
    /// Cells the explanation talks about, highlighted on the board.
    let highlight: Set<Int>
    var revealed = false
}
