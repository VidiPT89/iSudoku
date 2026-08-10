import SwiftUI

enum AppScreen {
    case splash, menu, howToPlay, game
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
                    onHowToPlay: { withAnimation(Theme.ease) { screen = .howToPlay } }
                )
            case .howToPlay:
                HowToPlayView(onClose: { withAnimation(Theme.ease) { screen = .menu } })
            case .game:
                GameView(
                    engine: engine,
                    onExit: {
                        SaveStore.save(engine)
                        hasSave = true
                        withAnimation(Theme.ease) { screen = .menu }
                    },
                    onNewGame: { startNewGame() }
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
}
