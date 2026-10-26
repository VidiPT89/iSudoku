import Foundation
import Combine

enum SudokuResult: Equatable {
    case cellSelected(Int)
    case digitEntered(index: Int, digit: Int)
    case cellCleared(Int)
    case noteToggled(index: Int, digit: Int)
    case undone
    case hintClue
    case hintRevealed(index: Int, digit: Int)
    case hintExhausted
    case won
    case ignored
}

struct NoteBackup: Codable {
    let index: Int
    let notes: Set<Int>
}

struct UndoEntry: Codable {
    let index: Int
    let prevValue: Int?
    let prevNotes: Set<Int>
    let peerNotes: [NoteBackup]
}

/// Owns the full mutable game state for one puzzle: cells, selection, notes-mode,
/// move/hint counters and elapsed time. Every public mutator returns a SudokuResult
/// describing what happened so the view layer can react (sound, animation, save,
/// modal) without re-deriving state.
final class GameEngine: ObservableObject {
    @Published private(set) var difficulty: Difficulty = .easy
    @Published private(set) var cells: [SudokuCell] = []
    @Published private(set) var selectedIndex: Int?
    @Published private(set) var notesMode = false
    @Published private(set) var moves = 0
    @Published private(set) var hintsUsed = 0
    @Published private(set) var wrongMoves = 0
    @Published private(set) var challengeLevel: Int? = nil
    /// Explanation of the latest hint, until the board changes again.
    @Published private(set) var lastHint: HintPlan?
    private var elapsedBeforeRun: Double = 0
    private var runningSince: TimeInterval? = ProcessInfo.processInfo.systemUptime

    var isChallenge: Bool { challengeLevel != nil }
    var maxHints: Int {
        if let level = challengeLevel { return maxHintsForLevel(level) }
        return difficulty.maxHints
    }

    private var givenMask = [Bool](repeating: false, count: 81)
    private var solution = [Int](repeating: 0, count: 81)
    private var values = [Int](repeating: 0, count: 81)
    private var notes = [Set<Int>](repeating: [], count: 81)
    private var undoStack: [UndoEntry] = []

    var hintsRemaining: Int { maxHints - hintsUsed }
    var canUndo: Bool { !undoStack.isEmpty }

    var elapsedSeconds: Double {
        elapsedBeforeRun + (runningSince.map { max(0, ProcessInfo.processInfo.systemUptime - $0) } ?? 0)
    }

    func pause() {
        elapsedBeforeRun = elapsedSeconds
        runningSince = nil
    }

    func resume() {
        if runningSince == nil && !isWon { runningSince = ProcessInfo.processInfo.systemUptime }
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
        applyGenerated(generated, difficulty: newDifficulty, level: nil)
    }

    /// Start a fresh Challenge-mode puzzle at the given ladder level. Clue count and hint budget
    /// come from the ramp; the mapped Difficulty is only kept so classic UI paths (leaderboard
    /// tags, digit-remaining pad) keep working unchanged.
    func resetChallenge(level: Int) {
        let band = bandForLevel(level)
        let generated = SudokuGenerator.generate(band, targetClues: cluesForLevel(level))
        applyGenerated(generated, difficulty: band, level: level)
    }

    private func applyGenerated(_ generated: GeneratedPuzzle, difficulty newDifficulty: Difficulty, level: Int?) {
        difficulty = newDifficulty
        challengeLevel = level
        givenMask = generated.given.map { $0 != 0 }
        solution = generated.solution
        values = generated.given
        notes = [Set<Int>](repeating: [], count: 81)
        undoStack = []
        lastHint = nil
        selectedIndex = nil
        notesMode = false
        moves = 0
        hintsUsed = 0
        wrongMoves = 0
        elapsedBeforeRun = 0
        runningSince = ProcessInfo.processInfo.systemUptime
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
        guard !isWon else { return .ignored }
        guard let index = selectedIndex, (0..<81).contains(index) else { return .ignored }
        guard !givenMask[index] else { return .ignored }
        guard (1...9).contains(digit) else { return .ignored }

        if notesMode {
            guard values[index] == 0 else { return .ignored }
            lastHint = nil
            let had = notes[index].contains(digit)
            pushUndo(index)
            if had { notes[index].remove(digit) } else { notes[index].insert(digit) }
            moves += 1
            rebuildCells()
            return .noteToggled(index: index, digit: digit)
        }

        if values[index] == digit { return .ignored }
        lastHint = nil
        pushUndo(index, digit: digit)
        values[index] = digit
        notes[index].removeAll()
        moves += 1
        if digit != solution[index] { wrongMoves += 1 }
        rebuildCells()
        if isWon { pause() }
        return isWon ? .won : .digitEntered(index: index, digit: digit)
    }

    @discardableResult
    func clearCell() -> SudokuResult {
        guard !isWon else { return .ignored }
        guard let index = selectedIndex, (0..<81).contains(index) else { return .ignored }
        guard !givenMask[index] else { return .ignored }
        guard values[index] != 0 || !notes[index].isEmpty else { return .ignored }
        lastHint = nil
        pushUndo(index)
        values[index] = 0
        notes[index].removeAll()
        moves += 1
        rebuildCells()
        return .cellCleared(index)
    }

    @discardableResult
    func undo() -> SudokuResult {
        guard !isWon else { return .ignored }
        guard let entry = undoStack.popLast() else { return .ignored }
        lastHint = nil
        values[entry.index] = entry.prevValue ?? 0
        notes[entry.index] = entry.prevNotes
        selectedIndex = entry.index
        for peer in entry.peerNotes { notes[peer.index] = peer.notes }
        rebuildCells()
        return .undone
    }

    func toggleNotesMode() {
        notesMode.toggle()
    }

    /// Plans the next hint without changing the board: a wrong entry first (the selected cell,
    /// else any); otherwise the simplest deduction — a single, possibly exposed by a short chain
    /// of eliminations — reasoning only from correct digits; a blind reveal only when nothing applies.
    func planHint() -> HintPlan? {
        let editable = { (i: Int) in !self.givenMask[i] && self.values[i] != self.solution[i] }
        let board = (0..<81).map { values[$0] == solution[$0] ? values[$0] : 0 }
        let index: Int
        var technique = HintTechnique.reveal
        var unit: SudokuUnit?
        var eliminations: [Elimination] = []
        func use(_ deduction: (single: SingleStep, eliminations: [Elimination])) {
            technique = deduction.single.technique
            unit = deduction.single.unit
            eliminations = deduction.eliminations
        }
        if let selected = selectedIndex, (0..<81).contains(selected), editable(selected) {
            index = selected
            if values[selected] != 0 { technique = .wrong }
            else if let deduction = Techniques.planDeduction(board, onlyIndex: selected) { use(deduction) }
        } else if let wrong = (0..<81).filter({ editable($0) && values[$0] != 0 }).randomElement() {
            index = wrong
            technique = .wrong
        } else if let deduction = Techniques.planDeduction(board) {
            index = deduction.single.index
            use(deduction)
        } else {
            guard let picked = (0..<81).filter(editable).randomElement() else { return nil }
            index = picked
        }
        var highlight = Set(unit?.cells ?? [])
        if technique == .wrong || technique == .naked { highlight.formUnion(SudokuUnit(kind: .row, index: index / 9).cells) }
        for elimination in eliminations { highlight.formUnion(elimination.cells) }
        return HintPlan(index: index, digit: solution[index], technique: technique, unit: unit, eliminations: eliminations, highlight: highlight)
    }

    /// First half of a hint: explains where to look without filling anything. Free.
    @discardableResult
    func clue() -> SudokuResult {
        guard !isWon else { return .ignored }
        guard let plan = planHint() else { return .hintExhausted }
        lastHint = plan
        return .hintClue
    }

    /// Fills the planned cell (the pending clue's, if one is showing) and costs a hint.
    @discardableResult
    func hint() -> SudokuResult {
        guard !isWon else { return .ignored }
        guard hintsUsed < maxHints else { return .hintExhausted }
        guard var plan = lastHint.flatMap({ $0.revealed ? nil : $0 }) ?? planHint() else { return .hintExhausted }

        let target = plan.index
        pushUndo(target, digit: plan.digit)
        values[target] = plan.digit
        notes[target].removeAll()
        hintsUsed += 1
        moves += 1
        selectedIndex = target
        plan.revealed = true
        lastHint = plan
        rebuildCells()
        if isWon { pause() }
        return isWon ? .won : .hintRevealed(index: target, digit: plan.digit)
    }

    static func arePeers(_ a: Int, _ b: Int) -> Bool {
        a != b && (a / 9 == b / 9 || a % 9 == b % 9 || (a / 27 == b / 27 && (a % 9) / 3 == (b % 9) / 3))
    }

    private func pushUndo(_ index: Int, digit: Int? = nil) {
        var peerNotes: [NoteBackup] = []
        if let digit = digit {
            for peer in 0..<81 where !givenMask[peer] && Self.arePeers(index, peer) && notes[peer].contains(digit) {
                peerNotes.append(NoteBackup(index: peer, notes: notes[peer]))
                notes[peer].remove(digit)
            }
        }
        let entry = UndoEntry(
            index: index,
            prevValue: values[index] == 0 ? nil : values[index],
            prevNotes: notes[index],
            peerNotes: peerNotes
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
            wrongMoves: wrongMoves,
            challengeLevel: challengeLevel,
            elapsedSeconds: elapsedSeconds,
            undoStack: undoStack
        )
    }

    @discardableResult
    func restore(from snapshot: SudokuSnapshot) -> Bool {
        guard snapshot.isValid else { return false }
        difficulty = Difficulty(rawValue: snapshot.difficulty) ?? .easy
        challengeLevel = snapshot.challengeLevel
        givenMask = snapshot.given.map { $0 != 0 }
        solution = snapshot.solution
        values = snapshot.values
        notes = snapshot.notes.map { Set($0) }
        undoStack = snapshot.undoStack ?? []
        lastHint = nil
        selectedIndex = snapshot.selectedIndex
        notesMode = snapshot.notesMode
        moves = snapshot.moves
        hintsUsed = snapshot.hintsUsed
        wrongMoves = snapshot.wrongMoves ?? 0
        elapsedBeforeRun = snapshot.elapsedSeconds
        runningSince = ProcessInfo.processInfo.systemUptime
        rebuildCells()
        return true
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
    var wrongMoves: Int? = nil
    var challengeLevel: Int? = nil
    var elapsedSeconds: Double
    var undoStack: [UndoEntry]? = nil

    var isValid: Bool {
        guard let band = Difficulty(rawValue: difficulty),
              given.count == 81, given.allSatisfy({ (0...1).contains($0) }),
              solution.count == 81, solution.allSatisfy({ (1...9).contains($0) }),
              values.count == 81, values.allSatisfy({ (0...9).contains($0) }),
              notes.count == 81, notes.allSatisfy({ $0.allSatisfy { (1...9).contains($0) } }),
              selectedIndex.map({ (0..<81).contains($0) }) ?? true,
              moves >= 0, hintsUsed >= 0, (wrongMoves ?? 0) >= 0,
              elapsedSeconds.isFinite, elapsedSeconds >= 0, elapsedSeconds < Double(Int.max / 1000),
              SudokuSolver.findConflictIndices(solution).isEmpty,
              (0..<81).allSatisfy({ given[$0] == 0 || values[$0] == solution[$0] }) else { return false }
        if let level = challengeLevel {
            guard level >= 1, level < Int.max - 100, band == bandForLevel(level) else { return false }
        }
        if let history = undoStack {
            guard history.count <= 200 else { return false }
            func editable(_ index: Int) -> Bool { (0..<81).contains(index) && given[index] == 0 }
            func validNotes(_ notes: Set<Int>) -> Bool { notes.allSatisfy { (1...9).contains($0) } }
            for entry in history {
                guard editable(entry.index), entry.prevValue.map({ (1...9).contains($0) }) ?? true,
                      validNotes(entry.prevNotes), entry.peerNotes.count <= 20,
                      Set(entry.peerNotes.map { $0.index }).count == entry.peerNotes.count,
                      entry.peerNotes.allSatisfy({ editable($0.index) && GameEngine.arePeers(entry.index, $0.index) && validNotes($0.notes) }) else { return false }
            }
        }
        return hintsUsed <= band.maxHints
    }
}
