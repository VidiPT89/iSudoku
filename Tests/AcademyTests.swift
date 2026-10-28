import Foundation

@main
enum AcademyTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
        checks += 1
        precondition(condition(), "Line \(line): \(message)")
    }

    static func main() {
        for lesson in Lesson.allCases {
            let started = Date()
            for _ in 0..<3 {
                guard let drill = Drill.make(lesson) else { check(false, "\(lesson) drill generated"); continue }
                check(!drill.answers.isEmpty, "\(lesson) has answers")
                check(drill.candidates == Techniques.candidateMasks(drill.grid), "\(lesson) shows the board's own candidates")
                check(drill.grid.enumerated().allSatisfy { $0.element == 0 || $0.element == drill.solution[$0.offset] }, "\(lesson) board is a correct partial solution")
                for answer in drill.answers {
                    check(drill.grid[answer.index] == 0, "\(lesson) answer on an empty cell")
                    if lesson.isSingle {
                        check(drill.solution[answer.index] == answer.digit, "\(lesson) single is the solution digit")
                    } else {
                        check(drill.solution[answer.index] != answer.digit, "\(lesson) never removes the solution digit")
                        check(drill.candidates[answer.index] & (1 << answer.digit) != 0, "\(lesson) removes a real candidate")
                        check(answer.elimination?.kind == lesson.eliminationKind, "\(lesson) answer uses the lesson's technique")
                    }
                    check(drill.check(index: answer.index, digit: answer.digit) == .correct(answer), "\(lesson) accepts every answer")
                }
                let first = drill.answers[0]
                if lesson.isSingle {
                    check(drill.check(index: first.index, digit: first.digit % 9 + 1) == .wrong, "\(lesson) rejects a wrong digit")
                } else {
                    check(drill.check(index: first.index, digit: drill.solution[first.index]) == .wrong, "\(lesson) cannot remove the answer")
                }
                if lesson == .nakedSingle {
                    let hidden = Set(Drill.answers(for: .hiddenSingle, candidates: drill.candidates).map(\.index))
                    check(drill.answers.contains { !hidden.contains($0.index) }, "naked drill needs reading candidates")
                }
            }
            let ms = Int(Date().timeIntervalSince(started) * 1000 / 3)
            print("\(lesson): \(ms) ms per drill")
            check(ms < 3000, "\(lesson) drill generation is fast enough")
        }
        let given = Array(repeating: 0, count: 81)
        check(Drill.answers(for: .xWing, candidates: given).isEmpty, "no x-wing on empty candidates")

        var progress = AcademyProgress()
        check(progress.recommended == .hiddenSingle, "start with hidden singles")
        for _ in 0..<7 { progress.recordSolved(.hiddenSingle, firstTry: true) }
        progress.recordSolved(.hiddenSingle, firstTry: false)
        check(progress.record(.hiddenSingle) == LessonRecord(solved: 8, firstTry: 7), "record counts")
        check(progress.record(.hiddenSingle).mastery == AcademyProgress.masteryGoal, "mastery capped")
        check(progress.recommended == .nakedSingle, "next lesson recommended")

        let pointingHint = HintPlan(index: 0, digit: 1, technique: .naked, unit: nil,
                                    eliminations: [Elimination(kind: .pointing, digits: [1], source: SudokuUnit(kind: .box, index: 0), target: SudokuUnit(kind: .row, index: 0), cells: [], removals: [])],
                                    highlight: [])
        check(Lesson.practising(pointingHint) == .pointing, "hint maps to its hardest technique")
        check(Lesson.practising(HintPlan(index: 0, digit: 1, technique: .wrong, unit: nil, eliminations: [], highlight: [])) == nil, "wrong-digit hint has no lesson")

        let key = "isudoku-academy"
        let store = AcademyStore()
        UserDefaults.standard.set(Data("{\"records\":{\"bogus\":{\"solved\":1,\"firstTry\":1},\"xWing\":{\"solved\":1,\"firstTry\":4}}}".utf8), forKey: key)
        check(store.load().records.isEmpty, "tampered records dropped")
        store.save(progress)
        check(store.load() == progress, "progress roundtrip")
        UserDefaults.standard.removeObject(forKey: key)

        Localization.shared.lang = .en
        for lesson in Lesson.allCases {
            for suffix in ["Name", "Idea", "Task"] {
                let key = "lesson_\(lesson.rawValue)_\(suffix)"
                check(Localization.shared.t(key) != key, "\(key) translated")
            }
        }
        print("AcademyTests.swift: \(checks) checks passed")
    }
}
