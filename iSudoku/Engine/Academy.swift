import Foundation

/// Technique Academy: one lesson per human technique the hint engine knows, each drilled on
/// positions taken from real generated puzzles rather than hand-made diagrams.
///
/// A drill is a partial board (givens plus some correct digits) whose candidates contain at least
/// one instance of the lesson's technique. Singles are answered by placing the digit; eliminations
/// by picking one candidate the technique removes. Any instance on the board counts, so the player
/// is never asked to guess which one the app had in mind.
enum Lesson: String, CaseIterable, Codable {
    case hiddenSingle, nakedSingle, pointing, claiming, nakedPair, xWing

    var isSingle: Bool { self == .hiddenSingle || self == .nakedSingle }

    var eliminationKind: Elimination.Kind? {
        switch self {
        case .pointing: return .pointing
        case .claiming: return .claiming
        case .nakedPair: return .pair
        case .xWing: return .xWing
        case .hiddenSingle, .nakedSingle: return nil
        }
    }

    /// 0 = basic, 1 = intermediate, 2 = advanced.
    var tier: Int {
        switch self {
        case .hiddenSingle, .nakedSingle: return 0
        case .pointing, .claiming, .nakedPair: return 1
        case .xWing: return 2
        }
    }

    /// The lesson that trains what a hint used: its hardest elimination, else its single.
    static func practising(_ hint: HintPlan) -> Lesson? {
        let kinds = hint.eliminations.map(\.kind)
        if kinds.contains(.xWing) { return .xWing }
        if kinds.contains(.pair) { return .nakedPair }
        if kinds.contains(.claiming) { return .claiming }
        if kinds.contains(.pointing) { return .pointing }
        switch hint.technique {
        case .hidden: return .hiddenSingle
        case .naked: return .nakedSingle
        case .wrong, .reveal: return nil
        }
    }
}

/// One deduction the player can find on a drill board: the digit placed (singles) or removed
/// (eliminations) at `index`, and the pattern that justifies it.
struct DrillAnswer: Equatable {
    let index: Int
    let digit: Int
    let single: SingleStep?
    let elimination: Elimination?

    /// Board cells the explanation talks about.
    var highlight: Set<Int> {
        if let e = elimination { return Set(e.cells) }
        if let unit = single?.unit { return Set(unit.cells) }
        return [index]
    }
}

struct Drill {
    let lesson: Lesson
    let grid: [Int]
    let solution: [Int]
    let candidates: [Int]
    let answers: [DrillAnswer]

    enum Verdict: Equatable {
        case correct(DrillAnswer)
        /// Singles: the digit is right but does not follow from this technique yet.
        /// Eliminations: the candidate is false, but this technique does not remove it yet.
        case notThisTechnique
        /// Eliminations: the cell has no such candidate.
        case notACandidate
        case wrong
    }

    func check(index: Int, digit: Int) -> Verdict {
        guard (0..<81).contains(index), (1...9).contains(digit), grid[index] == 0 else { return .wrong }
        if let answer = answers.first(where: { $0.index == index && $0.digit == digit }) { return .correct(answer) }
        if lesson.isSingle { return solution[index] == digit ? .notThisTechnique : .wrong }
        if candidates[index] & (1 << digit) == 0 { return .notACandidate }
        return solution[index] == digit ? .wrong : .notThisTechnique
    }

    /// Every deduction of `lesson` on these candidates; empty if the technique does not apply.
    static func answers(for lesson: Lesson, candidates masks: [Int]) -> [DrillAnswer] {
        var found: [DrillAnswer] = []
        switch lesson {
        case .hiddenSingle:
            for kind in [SudokuUnit.Kind.box, .row, .col] {
                for n in 0..<9 {
                    let unit = SudokuUnit(kind: kind, index: n)
                    for d in 1...9 {
                        let homes = unit.cells.filter { masks[$0] & (1 << d) != 0 }
                        guard homes.count == 1, !found.contains(where: { $0.index == homes[0] }) else { continue }
                        found.append(DrillAnswer(index: homes[0], digit: d, single: SingleStep(index: homes[0], digit: d, technique: .hidden, unit: unit), elimination: nil))
                    }
                }
            }
        case .nakedSingle:
            for i in 0..<81 where masks[i].nonzeroBitCount == 1 {
                let d = masks[i].trailingZeroBitCount
                found.append(DrillAnswer(index: i, digit: d, single: SingleStep(index: i, digit: d, technique: .naked, unit: nil), elimination: nil))
            }
        case .pointing, .claiming, .nakedPair, .xWing:
            Techniques.forEachElimination(masks) { e in
                guard e.kind == lesson.eliminationKind else { return false }
                for removal in e.removals {
                    for d in Techniques.digits(of: removal.bits) where !found.contains(where: { $0.index == removal.index && $0.digit == d }) {
                        found.append(DrillAnswer(index: removal.index, digit: d, single: nil, elimination: e))
                    }
                }
                return false
            }
        }
        return found
    }

    /// Walks generated puzzles forward one correct digit at a time until the lesson's technique
    /// shows up. Naked-single drills also need a cell no hidden single gives away, or the lesson
    /// could be passed without ever reading a cell's candidates.
    static func make(_ lesson: Lesson, maxPuzzles: Int = 40) -> Drill? {
        let (difficulty, clues): (Difficulty, Int) = lesson.isSingle ? (.medium, 32) : lesson == .xWing ? (.expert, 24) : (.hard, 26)
        // Keep enough empty cells that the board still has something to scan.
        let minEmpty = lesson.isSingle ? 35 : 30
        for _ in 0..<maxPuzzles {
            let puzzle = SudokuGenerator.generate(difficulty, targetClues: clues)
            var grid = puzzle.given
            var order = (0..<81).filter { grid[$0] == 0 }.shuffled()
            while order.count >= minEmpty {
                let masks = Techniques.candidateMasks(grid)
                let found = answers(for: lesson, candidates: masks)
                let usable = lesson != .nakedSingle || {
                    let hidden = Set(answers(for: .hiddenSingle, candidates: masks).map(\.index))
                    return found.contains { !hidden.contains($0.index) }
                }()
                if !found.isEmpty && usable {
                    return Drill(lesson: lesson, grid: grid, solution: puzzle.solution, candidates: masks, answers: found)
                }
                let next = order.removeLast()
                grid[next] = puzzle.solution[next]
            }
        }
        return nil
    }
}

/// Per-lesson record. Mastery counts drills solved without a miss or "show me", capped at
/// `AcademyProgress.masteryGoal`.
struct LessonRecord: Codable, Equatable {
    var solved = 0
    var firstTry = 0

    var mastery: Int { min(AcademyProgress.masteryGoal, firstTry) }
}

struct AcademyProgress: Codable, Equatable {
    static let masteryGoal = 5
    var records: [String: LessonRecord] = [:]

    func record(_ lesson: Lesson) -> LessonRecord { records[lesson.rawValue] ?? LessonRecord() }

    /// The first lesson not yet mastered, in teaching order.
    var recommended: Lesson? { Lesson.allCases.first { record($0).mastery < Self.masteryGoal } }

    mutating func recordSolved(_ lesson: Lesson, firstTry: Bool) {
        var r = record(lesson)
        r.solved = min(r.solved + 1, 1_000_000)
        if firstTry { r.firstTry = min(r.firstTry + 1, 1_000_000) }
        records[lesson.rawValue] = r
    }
}

final class AcademyStore {
    private let key = "isudoku-academy"

    func load() -> AcademyProgress {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AcademyProgress.self, from: data) else { return AcademyProgress() }
        // Drop unknown lessons and impossible counters from a tampered or older store.
        let valid = decoded.records.filter { Lesson(rawValue: $0.key) != nil && $0.value.solved >= 0 && (0...$0.value.solved).contains($0.value.firstTry) }
        return AcademyProgress(records: valid)
    }

    func save(_ progress: AcademyProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
