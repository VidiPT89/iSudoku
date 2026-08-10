import Foundation
import Combine

enum SudokuResult: Equatable {
    case cellSelected(Int)
    case digitEntered(index: Int, digit: Int)
    case cellCleared(Int)
    case noteToggled(index: Int, digit: Int)
    case undone
    case hintRevealed(index: Int, digit: Int)
    case hintExhausted
    case won
    case ignored
}

private struct UndoEntry {
    let index: Int
    let prevValue: Int?
    let prevNotes: Set<Int>
    let wasHint: Bool
}

/// Owns the full mutable game state for one puzzle: cells, selection, notes-mode,
/// move/hint counters and elapsed time. Every public mutator returns a SudokuResult
/// describing what happened so the view layer can react (sound, animation, save,
/// modal) without re-deriving state.
final class GameEngine: ObservableObject {
    @Published private(set) var difficulty: Difficulty = .easy
    @Published private(set) var cells: [SudokuCell] = []
    @Published var selectedIndex: Int?
    @Published private(set) var notesMode = false
    @Published private(set) var moves = 0
    @Published private(set) var hintsUsed = 0
    private(set) var startedAt = Date()

    private var givenMask = [Bool](repeating: false, count: 81)
    private var solution = [Int](repeating: 0, count: 81)
    private var values = [Int](repeating: 0, count: 81)
    private var notes = [Set<Int>](repeating: [], count: 81)
    private var undoStack: [UndoEntry] = []

    var hintsRemaining: Int { difficulty.maxHints - hintsUsed }
    var canUndo: Bool { !undoStack.isEmpty }

    var elapsedSeconds: Double {
        Date().timeIntervalSince(startedAt)
    }

    var isWon: Bool {
        if values.contains(0) { return false }
        return SudokuSolver.findConflictIndices(values).isEmpty
    }

    init() {
        reset(difficulty: .easy)
    }

    func reset(difficulty newDifficulty: Difficulty) {
        let generated = SudokuGenerator.generate(newDifficulty)
        difficulty = newDifficulty
        givenMask = generated.given.map { $0 != 0 }
        solution = generated.solution
        values = generated.given
        notes = [Set<Int>](repeating: [], count: 81)
        undoStack = []
        selectedIndex = nil
        notesMode = false
        moves = 0
        hintsUsed = 0
        startedAt = Date()
        rebuildCells()
    }

    private func rebuildCells() {
        let conflicts = SudokuSolver.findConflictIndices(values)
        cells = (0..<81).map { idx in
            SudokuCell(
                row: idx / 9,
                col: idx % 9,
                isGiven: givenMask[idx],
                value: values[idx] == 0 ? nil : values[idx],
                notes: notes[idx],
                isConflict: conflicts.contains(idx)
            )
        }
    }

    @discardableResult
    func selectCell(_ index: Int) -> SudokuResult {
        guard (0..<81).contains(index) else { return .ignored }
        selectedIndex = index
        return .cellSelected(index)
    }

    @discardableResult
    func enterDigit(_ digit: Int) -> SudokuResult {
        guard let index = selectedIndex else { return .ignored }
        guard !givenMask[index] else { return .ignored }
        guard (1...9).contains(digit) else { return .ignored }

        if notesMode {
            let had = notes[index].contains(digit)
            pushUndo(index)
            if had { notes[index].remove(digit) } else { notes[index].insert(digit) }
            moves += 1
            rebuildCells()
            return .noteToggled(index: index, digit: digit)
        }

        if values[index] == digit { return .ignored }
        pushUndo(index)
        values[index] = digit
        notes[index].removeAll()
        moves += 1
        rebuildCells()
        return isWon ? .won : .digitEntered(index: index, digit: digit)
    }

    @discardableResult
    func clearCell() -> SudokuResult {
        guard let index = selectedIndex else { return .ignored }
        guard !givenMask[index] else { return .ignored }
        guard values[index] != 0 || !notes[index].isEmpty else { return .ignored }
        pushUndo(index)
        values[index] = 0
        notes[index].removeAll()
        moves += 1
        rebuildCells()
        return .cellCleared(index)
    }

    @discardableResult
    func undo() -> SudokuResult {
        guard let entry = undoStack.popLast() else { return .ignored }
        values[entry.index] = entry.prevValue ?? 0
        notes[entry.index] = entry.prevNotes
        selectedIndex = entry.index
        if entry.wasHint && hintsUsed > 0 { hintsUsed -= 1 }
        rebuildCells()
        return .undone
    }

    func toggleNotesMode() {
        notesMode.toggle()
    }

    @discardableResult
    func hint() -> SudokuResult {
        guard hintsUsed < difficulty.maxHints else { return .hintExhausted }

        let target: Int
        if let selected = selectedIndex, !givenMask[selected], values[selected] != solution[selected] {
            target = selected
        } else {
            let candidates = (0..<81).filter { !givenMask[$0] && values[$0] != solution[$0] }
            guard let picked = candidates.randomElement() else { return .hintExhausted }
            target = picked
        }

        pushUndo(target, wasHint: true)
        values[target] = solution[target]
        notes[target].removeAll()
        hintsUsed += 1
        moves += 1
        selectedIndex = target
        rebuildCells()
        return isWon ? .won : .hintRevealed(index: target, digit: solution[target])
    }

    private func pushUndo(_ index: Int, wasHint: Bool = false) {
        let entry = UndoEntry(
            index: index,
            prevValue: values[index] == 0 ? nil : values[index],
            prevNotes: notes[index],
            wasHint: wasHint
        )
        undoStack.append(entry)
        if undoStack.count > 200 { undoStack.removeFirst() }
    }

    func remainingCount(for digit: Int) -> Int {
        9 - values.filter { $0 == digit }.count
    }

    func makeSnapshot() -> SudokuSnapshot {
        SudokuSnapshot(
            difficulty: difficulty.rawValue,
            given: givenMask.map { $0 ? 1 : 0 },
            solution: solution,
            values: values,
            notes: notes.map { Array($0) },
            selectedIndex: selectedIndex,
            notesMode: notesMode,
            moves: moves,
            hintsUsed: hintsUsed,
            elapsedSeconds: elapsedSeconds
        )
    }

    func restore(from snapshot: SudokuSnapshot) {
        difficulty = Difficulty(rawValue: snapshot.difficulty) ?? .easy
        givenMask = snapshot.given.map { $0 != 0 }
        solution = snapshot.solution
        values = snapshot.values
        notes = snapshot.notes.map { Set($0) }
        undoStack = []
        selectedIndex = snapshot.selectedIndex
        notesMode = snapshot.notesMode
        moves = snapshot.moves
        hintsUsed = snapshot.hintsUsed
        startedAt = Date().addingTimeInterval(-snapshot.elapsedSeconds)
        rebuildCells()
    }
}

struct SudokuSnapshot: Codable {
    var difficulty: String
    var given: [Int]
    var solution: [Int]
    var values: [Int]
    var notes: [[Int]]
    var selectedIndex: Int?
    var notesMode: Bool
    var moves: Int
    var hintsUsed: Int
    var elapsedSeconds: Double
}
