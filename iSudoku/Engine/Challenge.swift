import Foundation

/// Challenge mode: an endless ladder of generated levels.
///
/// Level 1 opens a shade easier than the classic EASY preset and every level shaves a fraction
/// of a clue off the grid, bottoming out at an expert floor below the classic HARD preset.
/// Because the ramp is a pure function of the level number there is no level content to author
/// or ship — the ladder simply never ends.
///
/// Stars rate a finished level on mistakes and hints only, never on time: a player who thinks
/// slowly is not a worse player.

/// Ramp knobs — tune these, not the formula.
private let challengeStartClues = 42
private let challengeMinClues = 23
private let challengeCluesPerLevel = 0.55

/// How much of the ladder the level picker keeps on screen at once.
let challengeLevelsBehind = 30
let challengeLevelsAhead = 5

/// Target clue count for a level, clamped so the ladder plateaus at the expert floor.
func cluesForLevel(_ level: Int) -> Int {
    let n = max(1, level)
    let target = Int(round(Double(challengeStartClues) - Double(n - 1) * challengeCluesPerLevel))
    return min(challengeStartClues, max(challengeMinClues, target))
}

/// Maps a level onto the classic difficulty vocabulary, for labels and hint budgets.
func bandForLevel(_ level: Int) -> Difficulty {
    let clues = cluesForLevel(level)
    switch clues {
    case 38...: return .easy
    case 32...37: return .medium
    case 26...31: return .hard
    default: return .expert
    }
}

func maxHintsForLevel(_ level: Int) -> Int {
    bandForLevel(level).maxHints
}

/// 3 = flawless, 2 = a few slips, 1 = finished. A mistake and a hint cost the same.
func starsFor(wrongMoves: Int, hintsUsed: Int) -> Int {
    let penalty = max(0, wrongMoves) + max(0, hintsUsed)
    switch penalty {
    case 0: return 3
    case 1...3: return 2
    default: return 1
    }
}

/// Pure progression rule, kept free of storage so it can be unit-tested: finishing a level
/// keeps the player's best result and only ever pushes the frontier forward.
struct ChallengeProgress: Codable, Equatable {
    var highestUnlocked: Int = 1
    var stars: [Int: Int] = [:]
    var bestTime: [Int: Double] = [:]

    var totalStars: Int { stars.values.reduce(0, +) }
    func starsAt(_ level: Int) -> Int { stars[level] ?? 0 }
    func isUnlocked(_ level: Int) -> Bool { level <= highestUnlocked }
}

struct ChallengeOutcome: Equatable {
    let improvedStars: Bool
    let isNewBestTime: Bool
    let unlockedNext: Bool
    let bestStars: Int
    let bestTimeSeconds: Double
}

func applyWin(
    progress: ChallengeProgress,
    level: Int,
    elapsedSeconds: Double,
    stars: Int
) -> (ChallengeProgress, ChallengeOutcome) {
    let prevStars = progress.stars[level] ?? 0
    let prevBest = progress.bestTime[level]

    let improvedStars = stars > prevStars
    let isNewBestTime = prevBest == nil || elapsedSeconds < prevBest!
    let unlockedNext = level >= progress.highestUnlocked

    var updated = progress
    if unlockedNext { updated.highestUnlocked = level + 1 }
    if improvedStars { updated.stars[level] = stars }
    if isNewBestTime { updated.bestTime[level] = elapsedSeconds }

    let outcome = ChallengeOutcome(
        improvedStars: improvedStars,
        isNewBestTime: isNewBestTime,
        unlockedNext: unlockedNext,
        bestStars: max(stars, prevStars),
        bestTimeSeconds: updated.bestTime[level] ?? elapsedSeconds
    )
    return (updated, outcome)
}

/// Persists challenge progress as a small JSON blob in UserDefaults.
final class ChallengeStore {
    private let key = "isudoku-challenges"

    func load() -> ChallengeProgress {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ChallengeProgress.self, from: data)
        else { return ChallengeProgress() }
        return decoded
    }

    func save(_ progress: ChallengeProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    @discardableResult
    func recordWin(level: Int, elapsedSeconds: Double, stars: Int) -> ChallengeOutcome {
        let (updated, outcome) = applyWin(progress: load(), level: level, elapsedSeconds: elapsedSeconds, stars: stars)
        save(updated)
        return outcome
    }
}