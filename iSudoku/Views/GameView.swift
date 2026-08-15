import SwiftUI

private enum ModalKind {
    case none, win, challengeWin, confirmRestart
}

struct GameView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var engine: GameEngine
    let onExit: () -> Void
    let onNewGame: () -> Void
    var onNextChallenge: () -> Void = {}
    var onChallengeLevels: () -> Void = {}
    var onChallengeWin: (_ level: Int, _ stars: Int, _ elapsedSeconds: Double) -> Void = { _, _, _ in }

    @State private var modal: ModalKind = .none
    @State private var toastMessage: String?
    @State private var shakeTokens: [Int: Int] = [:]
    @State private var recordEntry: LeaderboardEntry = LeaderboardEntry(bestTimeSeconds: nil, bestHints: nil)
    @State private var isNewBestTime = false
    @State private var isNewBestHints = false
    @State private var challengeOutcome: ChallengeOutcome? = nil
    @State private var challengeStars = 0

    var body: some View {
        ZStack {
            BackgroundGlow()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer(minLength: 12)

                SudokuGridView(
                    cells: engine.cells,
                    selectedIndex: engine.selectedIndex,
                    shakeTokens: shakeTokens,
                    onCellTap: handleTap
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 14)

                actionRow
                    .padding(.horizontal, 16)

                NumberPadView(
                    remainingCounts: (1...9).map { engine.remainingCount(for: $0) },
                    notesMode: engine.notesMode,
                    onDigit: handleDigit,
                    onErase: handleErase
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }

            if let message = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: message).padding(.bottom, 24)
                }
                .zIndex(500)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            switch modal {
            case .win:
                WinModalView(
                    time: formattedTime(engine.elapsedSeconds),
                    hintsUsed: engine.hintsUsed,
                    bestTime: recordEntry.bestTimeSeconds.map(formattedTime) ?? "–",
                    bestHints: recordEntry.bestHints.map { "\($0)" } ?? "–",
                    isNewBestTime: isNewBestTime,
                    isNewBestHints: isNewBestHints,
                    onPlayAgain: { performRestart() },
                    onMenu: { modal = .none; onExit() }
                ).zIndex(600)
            case .challengeWin:
                ChallengeWinModalView(
                    level: engine.challengeLevel ?? 0,
                    stars: challengeStars,
                    bestStars: challengeOutcome?.bestStars ?? challengeStars,
                    time: formattedTime(engine.elapsedSeconds),
                    bestTime: formattedTime(challengeOutcome?.bestTimeSeconds ?? engine.elapsedSeconds),
                    isNewBestTime: challengeOutcome?.isNewBestTime ?? false,
                    unlockedNext: challengeOutcome?.unlockedNext ?? false,
                    onNextLevel: { modal = .none; onNextChallenge() },
                    onLevels: { modal = .none; onChallengeLevels() }
                ).zIndex(600)
            case .confirmRestart:
                ConfirmModalView(
                    title: loc.t("confirmRestartTitle"),
                    message: loc.t("confirmRestartBody"),
                    onYes: { performRestart() },
                    onCancel: { modal = .none }
                ).zIndex(600)
            case .none:
                EmptyView()
            }
        }
        .onAppear { persist() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: { persist(); onExit() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.text)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.bgPanel2))
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                if let level = engine.challengeLevel {
                    statGroup(loc.t("level")) { Text("\(level)") }
                }
                statGroup(loc.t("time")) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(formattedTime(engine.elapsedSeconds))
                    }
                }
                statGroup(loc.t("moves")) { Text("\(engine.moves)") }
                statGroup(loc.t("hintsLeft")) { Text("\(engine.hintsRemaining)") }
            }
            .frame(maxWidth: .infinity)

            Button(action: { modal = .confirmRestart }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(Theme.text)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.bgPanel2))
            }
            .buttonStyle(.plain)
        }
    }

    private func statGroup<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 2) {
            value().font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text).monospacedDigit()
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 0) {
            actionButton(
                icon: "pencil",
                label: loc.t("notes"),
                active: engine.notesMode,
                disabled: false,
                action: { engine.toggleNotesMode() }
            )
            actionButton(
                icon: "arrow.uturn.backward",
                label: loc.t("undo"),
                active: false,
                disabled: !engine.canUndo,
                action: performUndo
            )
            actionButton(
                icon: "lightbulb",
                label: "\(loc.t("hint")) (\(engine.hintsRemaining))",
                active: false,
                disabled: engine.hintsRemaining <= 0,
                action: performHint
            )
        }
    }

    private func actionButton(icon: String, label: String, active: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(active ? Theme.accent : Theme.bgPanel2)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(disabled ? Theme.textFaint : (active ? Theme.bg : Theme.text))
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(disabled ? Theme.textFaint : Theme.textDim)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Actions

    private func persist() {
        SaveStore.save(engine)
    }

    private func handleResult(_ result: SudokuResult) {
        switch result {
        case .digitEntered(let index, _):
            SoundManager.digitEnter()
            persist()
            if engine.cells[index].isConflict {
                SoundManager.conflict()
                shakeTokens[index, default: 0] += 1
            }
        case .noteToggled:
            SoundManager.digitEnter()
            persist()
        case .cellCleared:
            persist()
        case .undone:
            persist()
        case .hintRevealed:
            SoundManager.hint()
            persist()
        case .hintExhausted:
            showToast(loc.t("noHintsLeft"))
        case .won:
            SoundManager.win()
            SaveStore.clear()
            if let level = engine.challengeLevel {
                let elapsed = engine.elapsedSeconds
                let stars = starsFor(wrongMoves: engine.wrongMoves, hintsUsed: engine.hintsUsed)
                challengeStars = stars
                challengeOutcome = ChallengeStore().recordWin(level: level, elapsedSeconds: elapsed, stars: stars)
                onChallengeWin(level, stars, elapsed)
                withAnimation(Theme.ease) { modal = .challengeWin }
            } else {
                let outcome = Leaderboard.recordCompletion(
                    difficulty: engine.difficulty,
                    timeSeconds: engine.elapsedSeconds,
                    hintsUsed: engine.hintsUsed
                )
                recordEntry = outcome.entry
                isNewBestTime = outcome.newBestTime
                isNewBestHints = outcome.newBestHints
                withAnimation(Theme.ease) { modal = .win }
            }
        case .cellSelected, .ignored:
            break
        }
    }

    private func handleTap(_ index: Int) {
        handleResult(engine.selectCell(index))
    }

    private func handleDigit(_ digit: Int) {
        handleResult(engine.enterDigit(digit))
    }

    private func handleErase() {
        handleResult(engine.clearCell())
    }

    private func performUndo() {
        guard engine.canUndo else {
            showToast(loc.t("nothingToUndo"))
            return
        }
        handleResult(engine.undo())
    }

    private func performHint() {
        handleResult(engine.hint())
    }

    private func performRestart() {
        modal = .none
        onNewGame()
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { toastMessage = nil }
        }
    }
}
