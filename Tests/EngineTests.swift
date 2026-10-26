import Foundation

@main
enum EngineTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
        checks += 1
        precondition(condition(), "Line \(line): \(message)")
    }
    static func main() {
        let engine = GameEngine()
        let original = engine.makeSnapshot()
        check(original.isValid, "fresh snapshot")
        check(SudokuSolver.countSolutions(Array(repeating: 1, count: 81)) == 0, "conflicting full board")
        check(SudokuSolver.countSolutions([1, 2]) == 0, "short board")
        check(SudokuSolver.countSolutions(original.solution, cap: 0) == 0, "zero cap")
        check(SudokuSolver.countSolutions(original.solution) == 1, "solved board")
        check(SudokuSolver.countSolutions(Array(repeating: 0, count: 81)) == 2, "multiple solutions")
        let corruptions: [(inout SudokuSnapshot) -> Void] = [
            { $0.values = [] }, { $0.solution = Array(repeating: 1, count: 81) },
            { $0.given[0] = 2 }, { $0.selectedIndex = 81 }, { $0.notes[0] = [10] },
            { $0.difficulty = "unknown" }, { $0.elapsedSeconds = -1 },
            { $0.elapsedSeconds = .infinity }, { $0.hintsUsed = 99 }, { $0.challengeLevel = 0 }
        ]
        for corrupt in corruptions {
            var invalid = original
            corrupt(&invalid)
            check(!invalid.isValid, "corrupt snapshot rejected")
            check(!engine.restore(from: invalid), "restore leaves live game intact")
            check(engine.makeSnapshot().values == original.values, "board preserved")
        }
        let target = original.values.firstIndex(of: 0)!
        engine.selectCell(target)
        engine.enterDigit(original.solution[target])
        check(engine.canUndo, "first move enables undo")
        engine.toggleNotesMode()
        check(engine.enterDigit(2) == .ignored, "no hidden notes on filled cells")
        engine.undo()
        check(engine.cells[target].value == nil, "undo clears entry")
        engine.enterDigit(2)
        engine.enterDigit(3)
        check(engine.cells[target].notes == [2, 3], "pencil marks")
        engine.undo()
        check(engine.cells[target].notes == [2], "undo notes")
        engine.toggleNotesMode()
        engine.hint()
        check(engine.hintsUsed == 1, "hint budget")
        engine.undo()
        check(engine.hintsUsed == 1 && engine.cells[target].notes == [2], "hint undo keeps cost and restores notes")
        var timed = original
        timed.elapsedSeconds = 123
        check(engine.restore(from: timed), "valid restore")
        engine.pause()
        let paused = engine.elapsedSeconds
        Thread.sleep(forTimeInterval: 0.02)
        check(engine.elapsedSeconds == paused, "pause freezes clock")
        engine.resume()
        Thread.sleep(forTimeInterval: 0.02)
        check(engine.elapsedSeconds > paused, "resume restarts clock")
        for difficulty in Difficulty.allCases {
            for _ in 0..<5 {
                let puzzle = SudokuGenerator.generate(difficulty)
                check(SudokuSolver.countSolutions(puzzle.given) == 1, "unique \(difficulty)")
                check(puzzle.given.enumerated().allSatisfy { $0.element == 0 || $0.element == puzzle.solution[$0.offset] }, "givens match")
                check(puzzle.given.filter { $0 != 0 }.count >= difficulty.minClues, "clue floor")
            }
        }
        engine.resetChallenge(level: 100)
        check(engine.makeSnapshot().isValid, "expert save")
        var almostWon = original
        almostWon.values = original.solution
        almostWon.values[target] = 0
        engine.restore(from: almostWon)
        engine.selectCell(target)
        check(engine.enterDigit(original.solution[target]) == .won, "last digit wins")
        let finished = engine.elapsedSeconds
        Thread.sleep(forTimeInterval: 0.02)
        check(engine.elapsedSeconds == finished, "victory freezes time")
        let digit = original.solution[0]
        let alternate = digit % 9 + 1
        var blank = original
        blank.given = Array(repeating: 0, count: 81)
        blank.values = Array(repeating: 0, count: 81)
        blank.notes = Array(repeating: [], count: 81)
        blank.notes[1] = [digit, alternate]
        for i in [9, 10, 40] { blank.notes[i] = [digit] }
        blank.undoStack = []
        engine.restore(from: blank)
        engine.selectCell(0)
        engine.enterDigit(digit)
        check(!engine.cells[1].notes.contains(digit), "row note cleared")
        check(engine.cells[1].notes.contains(alternate), "other candidate retained")
        check(!engine.cells[9].notes.contains(digit), "column note cleared")
        check(!engine.cells[10].notes.contains(digit), "box note cleared")
        check(engine.cells[40].notes.contains(digit), "unrelated note retained")
        let data = try! JSONEncoder().encode(engine.makeSnapshot())
        let saved = try! JSONDecoder().decode(SudokuSnapshot.self, from: data)
        check(engine.restore(from: saved) && engine.canUndo, "undo history survives JSON roundtrip")
        engine.undo()
        check(engine.cells[0].value == nil, "restored undo restores digit")
        check([1,9,10,40].allSatisfy { engine.cells[$0].notes.contains(digit) }, "restored undo restores peer notes")
        check(!engine.canUndo, "history consumed")
        for _ in 0..<engine.maxHints { engine.hint(); engine.undo() }
        check(engine.hintsUsed == engine.maxHints, "undo cannot refund hints")
        check(engine.hint() == .hintExhausted, "hint budget cannot be bypassed")
        let badEntries = [
            UndoEntry(index: 81, prevValue: nil, prevNotes: [], peerNotes: []),
            UndoEntry(index: 0, prevValue: 10, prevNotes: [], peerNotes: []),
            UndoEntry(index: 0, prevValue: nil, prevNotes: [0], peerNotes: []),
            UndoEntry(index: 0, prevValue: nil, prevNotes: [], peerNotes: [NoteBackup(index: 40, notes: [digit])])
        ]
        for bad in badEntries {
            var invalid = blank
            invalid.undoStack = [bad]
            check(!invalid.isValid, "invalid history rejected")
        }
        var legacy = blank
        legacy.undoStack = nil
        check(engine.restore(from: legacy) && !engine.canUndo, "legacy saves still load")
        engine.selectCell(0)
        engine.toggleNotesMode()
        for _ in 0..<205 { engine.enterDigit(1) }
        check(engine.makeSnapshot().undoStack?.count == 200, "history bounded")
        let boundedData = try! JSONEncoder().encode(engine.makeSnapshot())
        engine.restore(from: try! JSONDecoder().decode(SudokuSnapshot.self, from: boundedData))
        for _ in 0..<200 { engine.undo() }
        check(!engine.canUndo && engine.cells[0].notes.contains(1), "bounded history roundtrip")
        var solved = blank
        solved.values = original.solution
        engine.restore(from: solved)
        engine.selectCell(0)
        check(engine.enterDigit(alternate) == .ignored, "won game is immutable")
        check(engine.clearCell() == .ignored, "cannot clear won board")
        check(engine.undo() == .ignored, "cannot undo a recorded win")
        check(engine.hint() == .ignored, "cannot spend hint after win")
        print("EngineTests.swift: \(checks) checks passed")
    }
}
