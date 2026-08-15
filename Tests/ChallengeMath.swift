// Runnable check for the Swift challenge ladder. No XCTest, no scheme wiring:
//   swift run-tests/ChallengeMath.swift
// or the one-shot:
//   swift ../iSudoku/Engine/Challenge.swift Tests/ChallengeMath.swift
//
// Mirrors SudokuWeb/tests/challenge.test.js so the two implementations stay in step.

import Foundation

func check(_ cond: Bool, _ msg: String, file: StaticString = #file, line: UInt = #line) {
    if !cond { fatalError("assertion failed: \(msg) at \(file):\(line)") }
}

@main
enum ChallengeMathTests {
static func main() {
// Ramp is bounded to [floor, start] at every level, including junk input.
let starts = 42, floor = 23
for lvl in [1, 2, 5, 20, 50, 100, 500, 0, -3] {
    let c = cluesForLevel(lvl)
    check(c >= floor && c <= starts, "clues out of range at \(lvl): \(c)")
}

// Ramp never gets easier as levels rise.
var prev = Int.max
for lvl in 1...200 {
    let c = cluesForLevel(lvl)
    check(c <= prev, "ramp went easier at \(lvl): \(c) > \(prev)")
    prev = c
}

check(cluesForLevel(1) == starts, "level 1 must start at \(starts) clues")
check(cluesForLevel(100_000) == floor, "ladder must plateau at the expert floor")
check(bandForLevel(1) == .easy, "level 1 must be easy band")
check(bandForLevel(100_000) == .expert, "top of ladder must be expert band")
check(maxHintsForLevel(1) <= maxHintsForLevel(100_000), "hint budget must grow with difficulty")

// Stars: flawless / a-few-slips / messy.
check(starsFor(wrongMoves: 0, hintsUsed: 0) == 3, "flawless = 3 stars")
check(starsFor(wrongMoves: 1, hintsUsed: 0) == 2, "one slip = 2 stars")
check(starsFor(wrongMoves: 0, hintsUsed: 3) == 2, "three hints = 2 stars")
check(starsFor(wrongMoves: 2, hintsUsed: 2) == 1, "messy = 1 star")
check(starsFor(wrongMoves: 10, hintsUsed: 5) == 1, "very messy = 1 star")

// Progression: finishing top unlocks next; replay keeps best; frontier never regresses.
var progress = ChallengeProgress()
check(progress.highestUnlocked == 1, "fresh player starts at level 1")

var out: ChallengeOutcome
(progress, out) = applyWin(progress: progress, level: 1, elapsedSeconds: 120, stars: 3)
check(out.unlockedNext, "finishing top must unlock next")
check(progress.highestUnlocked == 2, "frontier advances after unlock")
check(progress.starsAt(1) == 3, "stars recorded")

(progress, out) = applyWin(progress: progress, level: 1, elapsedSeconds: 90, stars: 1)
check(!out.unlockedNext, "replay of old level does not unlock")
check(progress.highestUnlocked == 2, "frontier must not regress")
check(progress.starsAt(1) == 3, "stars must keep the best")
check(progress.bestTime[1] == 90, "best time must improve")

(progress, _) = applyWin(progress: progress, level: 2, elapsedSeconds: 200, stars: 1)
(progress, _) = applyWin(progress: progress, level: 2, elapsedSeconds: 200, stars: 2)
check(progress.starsAt(2) == 2, "better replay star count is kept")
check(progress.totalStars == 5, "totalStars sums per-level bests")

print("ChallengeMath.swift: all assertions passed")
}
}
