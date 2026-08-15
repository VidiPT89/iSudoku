import SwiftUI

/// Endless-ladder picker. Mirrors the Droid/Web layout: back arrow + title, a
/// "level reached / stars" summary, an optional "show earlier" button that
/// only walks the window backwards, and a grid of level tiles that colour
/// themselves by band and light up their stars as the player earns them.
struct ChallengesScreen: View {
    @EnvironmentObject var loc: Localization
    let progress: ChallengeProgress
    let onBack: () -> Void
    let onPickLevel: (Int) -> Void

    // Oldest level kept on screen; only ever walked backwards by "show earlier".
    @State private var windowStart: Int

    init(progress: ChallengeProgress, onBack: @escaping () -> Void, onPickLevel: @escaping (Int) -> Void) {
        self.progress = progress
        self.onBack = onBack
        self.onPickLevel = onPickLevel
        _windowStart = State(initialValue: max(1, progress.highestUnlocked - challengeLevelsBehind + 1))
    }

    private var levels: [Int] {
        let end = progress.highestUnlocked + challengeLevelsAhead
        return Array(max(1, windowStart)...max(max(1, windowStart), end))
    }

    var body: some View {
        ZStack {
            BackgroundGlow()

            VStack(spacing: 0) {
                header
                summary
                Text(loc.t("challengesSubtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)

                if windowStart > 1 {
                    Button(loc.t("showEarlier")) {
                        windowStart = max(1, windowStart - challengeLevelsBehind)
                    }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 72), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(levels, id: \.self) { level in
                            LevelTile(
                                level: level,
                                unlocked: progress.isUnlocked(level),
                                isCurrent: level == progress.highestUnlocked,
                                stars: progress.starsAt(level),
                                onTap: { onPickLevel(level) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.text)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.bgPanel2))
            }
            .buttonStyle(.plain)
            Text(loc.t("challengesTitle"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.text)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
    }

    private var summary: some View {
        HStack(spacing: 40) {
            SummaryStat(label: loc.t("levelReached"), value: "\(progress.highestUnlocked)")
            SummaryStat(label: loc.t("starsLabel"), value: "\(progress.totalStars)")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

private struct SummaryStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textFaint)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.accent)
        }
    }
}

private func bandColor(_ level: Int) -> Color {
    switch bandForLevel(level) {
    case .easy: return Theme.accentLight
    case .medium: return Theme.accent
    case .hard: return Theme.accentDark
    case .expert: return Theme.danger
    }
}

private struct LevelTile: View {
    let level: Int
    let unlocked: Bool
    let isCurrent: Bool
    let stars: Int
    let onTap: () -> Void

    var body: some View {
        let band = bandColor(level)
        let borderColor: Color = {
            if isCurrent { return band }
            if stars > 0 { return band.opacity(0.55) }
            return Theme.border
        }()

        Button(action: { if unlocked { onTap() } }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(unlocked ? Theme.bgPanel2 : Theme.bgPanel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: isCurrent ? 2 : 1)
                    )
                if unlocked {
                    VStack(spacing: 3) {
                        Text("\(level)")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Theme.text)
                        HStack(spacing: 1) {
                            ForEach(1...3, id: \.self) { i in
                                Text("★")
                                    .font(.system(size: 10))
                                    .foregroundColor(i <= stars ? band : Theme.textFaint)
                            }
                        }
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundColor(Theme.textFaint)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}
