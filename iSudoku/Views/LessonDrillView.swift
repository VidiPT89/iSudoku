import SwiftUI

/// One Academy lesson: the technique's idea, then an endless run of drills on real boards with
/// every candidate shown. Singles are answered by placing a digit, eliminations by picking the
/// candidate to remove. A drill solved without a miss or "show me" counts towards mastery.
struct LessonDrillView: View {
    @EnvironmentObject var loc: Localization
    let lesson: Lesson
    let onBack: () -> Void
    /// Called after each solved drill so the lesson list can refresh.
    var onProgress: (AcademyProgress) -> Void = { _ in }

    @State private var drill: Drill?
    @State private var failed = false
    @State private var round = 0
    @State private var selected: Int?
    @State private var missed = false
    @State private var answer: DrillAnswer?
    @State private var feedback: String?
    @State private var shakeTokens: [Int: Int] = [:]
    @State private var record = LessonRecord()

    private let store = AcademyStore()

    var body: some View {
        ZStack {
            BackgroundGlow()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 10) {
                        header
                        panel(loc.t("lesson_\(lesson.rawValue)_Idea"), accent: false)

                        Text(loc.t("lesson_\(lesson.rawValue)_Task"))
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundColor(Theme.accentLight)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(loc.fill("drillStats", ["n": "\(record.mastery)", "goal": "\(AcademyProgress.masteryGoal)", "s": "\(record.solved)"]))
                            .font(.system(.caption, weight: .medium))
                            .foregroundColor(Theme.textFaint)
                            .monospacedDigit()

                        board(geometry)

                        if let feedback {
                            panel(feedback, accent: true)
                        }

                        if answer != nil {
                            Button(loc.t("drillNext")) { round += 1 }
                                .buttonStyle(PrimaryButtonStyle())
                        } else if drill != nil {
                            Button(loc.t("drillShowMe"), action: showMe)
                                .buttonStyle(GhostButtonStyle())
                        }

                        NumberPadView(
                            remainingCounts: Array(repeating: 9, count: 9),
                            notesMode: !lesson.isSingle,
                            onDigit: enter,
                            onErase: {}
                        )
                        .disabled(drill == nil || answer != nil)
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: geometry.size.width >= 700 ? 760 : 560)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { record = store.load().record(lesson) }
        .task(id: round) { await loadDrill() }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left", label: loc.t("backToAcademy"), action: onBack)
            VStack(alignment: .leading, spacing: 1) {
                Text(loc.t("lesson_\(lesson.rawValue)_Name"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(loc.t("tier\(lesson.tier)"))
                    .font(.system(.caption, weight: .medium))
                    .foregroundColor(Theme.textFaint)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func board(_ geometry: GeometryProxy) -> some View {
        let side = min(geometry.size.width >= 700 ? 720 : 528, max(240, geometry.size.height - 300))
        if let drill {
            SudokuGridView(
                cells: cells(for: drill),
                selectedIndex: selected,
                shakeTokens: shakeTokens,
                hintUnit: answer?.highlight ?? [],
                onCellTap: { index in
                    guard answer == nil else { return }
                    selected = index
                }
            )
            .frame(maxWidth: side)
        } else {
            VStack(spacing: 12) {
                if failed {
                    Text(loc.t("drillFailed")).foregroundColor(Theme.textDim)
                    Button(loc.t("retry")) { round += 1 }.buttonStyle(SecondaryButtonStyle())
                } else {
                    ProgressView().tint(Theme.accent)
                    Text(loc.t("drillLoading")).font(.system(.footnote)).foregroundColor(Theme.textDim)
                }
            }
            .frame(maxWidth: side, minHeight: side * 0.6)
        }
    }

    private func panel(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.system(.footnote))
            .foregroundColor(accent ? Theme.text : Theme.textDim)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgPanel))
            .overlay(alignment: .leading) { Rectangle().fill(accent ? Theme.accent : Theme.borderStrong).frame(width: 3) }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// The drill board with every candidate shown; once answered, the single is filled in or the
    /// pattern's eliminations are taken out.
    private func cells(for drill: Drill) -> [SudokuCell] {
        var values = drill.grid
        var masks = drill.candidates
        var struck = [Int](repeating: 0, count: 81)
        if let answer {
            if let elimination = answer.elimination {
                for removal in elimination.removals { struck[removal.index] |= removal.bits }
                Techniques.apply(elimination, to: &masks)
            } else {
                values[answer.index] = answer.digit
            }
        }
        return (0..<81).map { i in
            SudokuCell(row: i / 9, col: i % 9, isGiven: drill.grid[i] != 0,
                       value: values[i] == 0 ? nil : values[i],
                       notes: values[i] == 0 ? Set(Techniques.digits(of: masks[i])) : [],
                       struckNotes: Set(Techniques.digits(of: struck[i])))
        }
    }

    private func loadDrill() async {
        drill = nil
        failed = false
        selected = nil
        missed = false
        answer = nil
        feedback = nil
        let lesson = self.lesson
        let made = await Task.detached(priority: .userInitiated) { Drill.make(lesson) }.value
        guard !Task.isCancelled else { return }
        drill = made
        failed = made == nil
    }

    private func enter(_ digit: Int) {
        guard let drill, answer == nil else { return }
        guard let index = selected, drill.grid[index] == 0 else {
            feedback = loc.t("drillPickCell")
            return
        }
        let d = ["d": "\(digit)"]
        switch drill.check(index: index, digit: digit) {
        case .correct(let found):
            withAnimation(Theme.ease) { answer = found }
            SoundManager.hint()
            feedback = loc.t("drillCorrect") + "\n" + explanation(found)
            var progress = store.load()
            progress.recordSolved(lesson, firstTry: !missed)
            store.save(progress)
            record = progress.record(lesson)
            onProgress(progress)
        case .notThisTechnique:
            missed = true
            feedback = loc.fill(lesson.isSingle ? "drillNotThisSingle" : "drillNotThisElim", d)
        case .notACandidate:
            feedback = loc.fill("drillNotCandidate", d)
        case .wrong:
            missed = true
            SoundManager.conflict()
            shakeTokens[index, default: 0] += 1
            feedback = loc.fill(lesson.isSingle ? "drillWrongSingle" : "drillWrongElim", d)
        }
    }

    /// Reveals one answer, preferring the selected cell. Not counted as solved.
    private func showMe() {
        guard let drill, answer == nil, let pick = drill.answers.first(where: { $0.index == selected }) ?? drill.answers.first else { return }
        selected = pick.index
        withAnimation(Theme.ease) { answer = pick }
        feedback = loc.t("drillShown") + "\n" + explanation(pick)
    }

    private func explanation(_ answer: DrillAnswer) -> String {
        if let elimination = answer.elimination { return loc.eliminationText(elimination) }
        let key: String
        switch answer.single?.unit?.kind {
        case .box: key = "hintHiddenBox"
        case .row: key = "hintHiddenRow"
        case .col: key = "hintHiddenCol"
        case nil: key = "hintNaked"
        }
        return loc.fill(key, ["r": "\(answer.index / 9 + 1)", "c": "\(answer.index % 9 + 1)", "d": "\(answer.digit)"])
    }
}
