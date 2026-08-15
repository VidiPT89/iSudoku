import SwiftUI

enum AppScreen {
    case splash, menu, howToPlay, game, levels
}

final class DifficultyStore: ObservableObject {
    @Published var value: Difficulty {
        didSet { UserDefaults.standard.set(value.rawValue, forKey: "isudoku-difficulty") }
    }

    init() {
        if let stored = UserDefaults.standard.string(forKey: "isudoku-difficulty"), let d = Difficulty(rawValue: stored) {
            value = d
        } else {
            value = .easy
        }
    }
}

struct RootView: View {
    @StateObject private var loc = Localization.shared
    @StateObject private var engine = GameEngine()
    @StateObject private var difficultyStore = DifficultyStore()
    @State private var screen: AppScreen = .splash
    @State private var hasSave = SaveStore.hasSave()
    @State private var challengeProgress = ChallengeStore().load()

    private let challengeStore = ChallengeStore()

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                SplashView { goToMenu() }
            case .menu:
                MainMenuView(
                    hasSave: hasSave,
                    selectedDifficulty: $difficultyStore.value,
                    onPlay: { startNewGame() },
                    onContinue: { continueGame() },
                    onChallenges: { openLevels() },
                    onHowToPlay: { withAnimation(Theme.ease) { screen = .howToPlay } }
                )
            case .howToPlay:
                HowToPlayView(onClose: { withAnimation(Theme.ease) { screen = .menu } })
            case .levels:
                ChallengesScreen(
                    progress: challengeProgress,
                    onBack: { withAnimation(Theme.ease) { screen = .menu } },
                    onPickLevel: { startChallenge($0) }
                )
            case .game:
                GameView(
                    engine: engine,
                    onExit: {
                        SaveStore.save(engine)
                        hasSave = true
                        let dest: AppScreen = engine.isChallenge ? .levels : .menu
                        withAnimation(Theme.ease) { screen = dest }
                    },
                    onNewGame: { restartCurrent() },
                    onNextChallenge: {
                        let next = (engine.challengeLevel ?? 0) + 1
                        startChallenge(next)
                    },
                    onChallengeLevels: { openLevels() },
                    onChallengeWin: { _, _, _ in
                        // GameView already persisted via ChallengeStore; just refresh our copy.
                        challengeProgress = challengeStore.load()
                    }
                )
            }
        }
        .environmentObject(loc)
        .transition(.opacity)
    }

    private func goToMenu() {
        withAnimation(.easeOut(duration: 0.5)) { screen = .menu }
    }

    private func startNewGame() {
        withAnimation(Theme.ease) { engine.reset(difficulty: difficultyStore.value) }
        SaveStore.clear()
        hasSave = false
        withAnimation(Theme.ease) { screen = .game }
    }

    private func continueGame() {
        if let snapshot = SaveStore.load() {
            engine.restore(from: snapshot)
        } else {
            engine.reset(difficulty: difficultyStore.value)
        }
        withAnimation(Theme.ease) { screen = .game }
    }

    private func openLevels() {
        challengeProgress = challengeStore.load()
        withAnimation(Theme.ease) { screen = .levels }
    }

    private func startChallenge(_ level: Int) {
        withAnimation(Theme.ease) { engine.resetChallenge(level: level) }
        SaveStore.clear()
        hasSave = false
        withAnimation(Theme.ease) { screen = .game }
    }

    private func restartCurrent() {
        if let level = engine.challengeLevel {
            engine.resetChallenge(level: level)
        } else {
            engine.reset(difficulty: difficultyStore.value)
        }
        SaveStore.clear()
    }
}
