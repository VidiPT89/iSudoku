import Foundation

/// Human solving techniques over a candidate grid, used to explain hints and to grade puzzles:
/// - singles: a digit with one possible cell in a box/row/column (hidden), or a cell with one
///   possible digit (naked);
/// - eliminations: pointing (a box's candidates for a digit sit on one line), claiming (a line's
///   candidates for a digit sit in one box) and naked pairs.
/// Candidates are 9-bit masks (bit d = digit d); filled cells have mask 0.
enum Techniques {
    private static let boxOrder: [SudokuUnit.Kind] = [.box, .row, .col]
    private static let peers: [[Int]] = (0..<81).map { idx in
        let units = [SudokuUnit(kind: .row, index: idx / 9), SudokuUnit(kind: .col, index: idx % 9), SudokuUnit(kind: .box, index: boxOf(idx))]
        return Array(Set(units.flatMap(\.cells)).subtracting([idx])).sorted()
    }

    static func boxOf(_ idx: Int) -> Int { (idx / 27) * 3 + (idx % 9) / 3 }

    static func candidateMasks(_ grid: [Int]) -> [Int] {
        var rows = [Int](repeating: 0, count: 9), cols = rows, boxes = rows
        for idx in 0..<81 where grid[idx] != 0 {
            let bit = 1 << grid[idx]
            rows[idx / 9] |= bit; cols[idx % 9] |= bit; boxes[boxOf(idx)] |= bit
        }
        return (0..<81).map { grid[$0] != 0 ? 0 : ~(rows[$0 / 9] | cols[$0 % 9] | boxes[boxOf($0)]) & 0x3fe }
    }

    static func digits(of mask: Int) -> [Int] { (1...9).filter { mask & (1 << $0) != 0 } }

    /// One single on the given candidates (boxes first — the easiest to spot), or nil.
    /// `onlyIndex` restricts the search to deductions that fill that cell.
    static func findSingle(in masks: [Int], onlyIndex: Int? = nil) -> SingleStep? {
        for kind in boxOrder {
            for n in 0..<9 {
                let unit = SudokuUnit(kind: kind, index: n)
                let cells = unit.cells
                if let only = onlyIndex, !cells.contains(only) { continue }
                // Digits seen in exactly one cell of the unit: once & ~twice.
                var once = 0, twice = 0
                for i in cells { twice |= once & masks[i]; once |= masks[i] }
                var unique = once & ~twice
                if let only = onlyIndex { unique &= masks[only] }
                guard unique != 0, let digit = digits(of: unique).first,
                      let index = cells.first(where: { masks[$0] & (1 << digit) != 0 }) else { continue }
                return SingleStep(index: index, digit: digit, technique: .hidden, unit: unit)
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

    /// First elimination that removes at least one candidate, or nil.
    static func findElimination(_ masks: [Int]) -> Elimination? {
        func removals(in cells: [Int], keeping keep: [Int], bits: Int) -> [Elimination.Removal] {
            cells.filter { !keep.contains($0) && masks[$0] & bits != 0 }.map { Elimination.Removal(index: $0, bits: masks[$0] & bits) }
        }
        for b in 0..<9 {
            let box = SudokuUnit(kind: .box, index: b)
            for d in 1...9 {
                let homes = box.cells.filter { masks[$0] & (1 << d) != 0 }
                guard homes.count >= 2 else { continue }
                for line in [SudokuUnit(kind: .row, index: homes[0] / 9), SudokuUnit(kind: .col, index: homes[0] % 9)]
                where homes.allSatisfy({ line.cells.contains($0) }) {
                    let cut = removals(in: line.cells, keeping: homes, bits: 1 << d)
                    if !cut.isEmpty { return Elimination(kind: .pointing, digits: [d], source: box, target: line, cells: homes, removals: cut) }
                }
            }
        }
        for kind in [SudokuUnit.Kind.row, .col] {
            for n in 0..<9 {
                let line = SudokuUnit(kind: kind, index: n)
                for d in 1...9 {
                    let homes = line.cells.filter { masks[$0] & (1 << d) != 0 }
                    guard homes.count >= 2, homes.allSatisfy({ boxOf($0) == boxOf(homes[0]) }) else { continue }
                    let box = SudokuUnit(kind: .box, index: boxOf(homes[0]))
                    let cut = removals(in: box.cells, keeping: homes, bits: 1 << d)
                    if !cut.isEmpty { return Elimination(kind: .claiming, digits: [d], source: line, target: box, cells: homes, removals: cut) }
                }
            }
        }
        for kind in boxOrder {
            for n in 0..<9 {
                let unit = SudokuUnit(kind: kind, index: n)
                let pairs = unit.cells.filter { masks[$0].nonzeroBitCount == 2 }
                for (a, first) in pairs.enumerated() {
                    for second in pairs[(a + 1)...] where masks[first] == masks[second] {
                        let cut = removals(in: unit.cells, keeping: [first, second], bits: masks[first])
                        if !cut.isEmpty {
                            return Elimination(kind: .pair, digits: digits(of: masks[first]), source: unit, target: unit, cells: [first, second], removals: cut)
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

    /// True when the grid can be completed by forced steps only: singles, plus the eliminations
    /// when `withEliminations` is set. Every step is forced, so a grid that passes also has
    /// exactly one solution.
    static func solvesLogically(_ grid: [Int], withEliminations: Bool = false) -> Bool {
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
            guard withEliminations, let elimination = findElimination(masks) else { return false }
            apply(elimination, to: &masks)
        }
        return SudokuSolver.findConflictIndices(work).isEmpty
    }
}

struct SudokuUnit: Equatable {
    enum Kind { case row, col, box }
    let kind: Kind
    let index: Int

    /// Cell indices (boxes numbered left-to-right, top-to-bottom).
    var cells: [Int] {
        switch kind {
        case .row: return (0..<9).map { index * 9 + $0 }
        case .col: return (0..<9).map { $0 * 9 + index }
        case .box:
            let r0 = (index / 3) * 3, c0 = (index % 3) * 3
            return (0..<9).map { (r0 + $0 / 3) * 9 + c0 + $0 % 3 }
        }
    }
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
    enum Kind { case pointing, claiming, pair }
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
