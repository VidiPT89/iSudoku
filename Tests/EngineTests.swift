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
        check(engine.hintsUsed == 0 && engine.cells[target].notes == [2], "hint undo restores budget and notes")
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
        print("EngineTests.swift: \(checks) checks passed")
    }
}
