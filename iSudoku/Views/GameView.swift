import SwiftUI

private enum ModalKind {
    case none, win, challengeWin, confirmRestart
}

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SoundManager.enabledKey) private var soundOn = true
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

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        Text(modeLine)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textDim)
                            .padding(.top, 8)
                        Spacer(minLength: 12)

                        SudokuGridView(
                            cells: engine.cells,
                            selectedIndex: engine.selectedIndex,
                            shakeTokens: shakeTokens,
                            hintUnit: engine.lastHint?.highlight ?? [],
                            onCellTap: handleTap
                        )
                        .frame(maxWidth: min(528, max(240, geometry.size.height - (engine.lastHint == nil ? 310 : 360))))
                        .padding(.horizontal, 16)

                        if let hint = engine.lastHint {
                            hintExplanation(loc.hintExplanation(hint))
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                        }

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
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .background(arrowKeyShortcuts)
            }
            .disabled(modal != .none)
            .accessibilityHidden(modal != .none)

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
        .onAppear { if scenePhase == .active { engine.resume() }; persist() }
        .onDisappear { engine.pause(); persist() }
        .onChange(of: scenePhase) { phase in
            if phase == .active && modal == .none { engine.resume() }
            else { engine.pause(); persist() }
        }
        .onChange(of: modal) { value in
            if value == .none && scenePhase == .active { engine.resume() }
            else { engine.pause(); persist() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            CircleIconButton(systemName: "chevron.left", label: loc.t("backToMenu")) { persist(); onExit() }

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

            CircleIconButton(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", label: loc.t("sound")) { soundOn.toggle() }
                .accessibilityValue(loc.t(soundOn ? "on" : "off"))
            CircleIconButton(systemName: "arrow.clockwise", label: loc.t("newGame")) { modal = .confirmRestart }
        }
    }

    private func hintExplanation(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote))
            .foregroundColor(Theme.textDim)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 528, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgPanel))
            .overlay(alignment: .leading) { Rectangle().fill(Theme.accent).frame(width: 3) }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Difficulty band, plus the mistake count that drives challenge stars.
    private var modeLine: String {
        let band = loc.t(engine.difficulty.rawValue)
        return engine.isChallenge ? "\(band) · \(loc.t("mistakes")): \(engine.wrongMoves)" : band
    }

    /// Invisible buttons so a hardware keyboard (Mac, iPad) can move the selection.
    private var arrowKeyShortcuts: some View {
        ZStack {
            Button("") { moveSelection(rows: -1, cols: 0) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("") { moveSelection(rows: 1, cols: 0) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("") { moveSelection(rows: 0, cols: -1) }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { moveSelection(rows: 0, cols: 1) }.keyboardShortcut(.rightArrow, modifiers: [])
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func statGroup<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 2) {
            value().font(.system(.subheadline, weight: .medium)).foregroundColor(Theme.text).monospacedDigit()
            Text(label).font(.system(.caption2, weight: .medium)).foregroundColor(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 8) {
            actionButton(
                icon: "pencil",
                activeIcon: "pencil.circle.fill",
                label: loc.t("notes"),
                active: engine.notesMode,
                disabled: false,
                action: { engine.toggleNotesMode(); persist() }
            )
            .keyboardShortcut("n", modifiers: [])
            actionButton(
                icon: "arrow.uturn.backward",
                label: loc.t("undo"),
                active: false,
                disabled: !engine.canUndo,
                action: performUndo
            )
            .keyboardShortcut("z", modifiers: .command)
            actionButton(
                icon: "lightbulb",
                activeIcon: "lightbulb.fill",
                label: engine.lastHint?.revealed == false ? loc.t("reveal") : "\(loc.t("hint")) (\(engine.hintsRemaining))",
                active: engine.lastHint?.revealed == false,
                disabled: false,
                action: performHint
            )
        }
    }

    private func actionButton(icon: String, activeIcon: String? = nil, label: String, active: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: active ? activeIcon ?? icon : icon)
                    .font(.system(size: 20))
                Text(label).font(.system(.caption, weight: .medium))
            }
            .foregroundColor(disabled ? Theme.textFaint : (active ? Theme.accentLight : Theme.textDim))
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 10).fill(active ? Theme.selectedCellBg : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(active ? Theme.accent : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
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
        case .hintClue:
            break
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

    private func moveSelection(rows: Int, cols: Int) {
        let current = engine.selectedIndex ?? 0
        let row = min(8, max(0, current / 9 + rows))
        let col = min(8, max(0, current % 9 + cols))
        handleTap(row * 9 + col)
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

    /// First press shows a free clue; pressing again while it is showing reveals the cell.
    private func performHint() {
        handleResult(engine.lastHint?.revealed == false ? engine.hint() : engine.clue())
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
