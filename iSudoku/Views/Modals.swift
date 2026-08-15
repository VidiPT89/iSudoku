import SwiftUI

struct ModalOverlay<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                content
            }
            .padding(26)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.bgPanel)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.borderStrong, lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            )
            .padding(24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

struct WinModalView: View {
    @EnvironmentObject var loc: Localization
    let time: String
    let hintsUsed: Int
    let bestTime: String
    let bestHints: String
    let isNewBestTime: Bool
    let isNewBestHints: Bool
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ModalOverlay {
            Text("🎉").font(.system(size: 44))
            Text(loc.t("winTitle")).font(.system(size: 24, weight: .bold)).foregroundColor(Theme.text)
            Text(loc.t("winSubtitle")).font(.system(size: 14)).foregroundColor(Theme.textDim).multilineTextAlignment(.center)

            HStack(spacing: 20) {
                statBlock(loc.t("time"), time)
                statBlock(loc.t("hintsLeft"), "\(hintsUsed)")
            }
            .padding(.vertical, 6)

            leaderboardBlock

            Button(loc.t("playAgain"), action: onPlayAgain).buttonStyle(PrimaryButtonStyle())
            Button(loc.t("backToMenu"), action: onMenu).buttonStyle(GhostButtonStyle())
        }
    }

    private var leaderboardBlock: some View {
        VStack(spacing: 8) {
            HStack {
                Text(loc.t("bestTime")).font(.system(size: 13)).foregroundColor(Theme.textDim)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(bestTime).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                    if isNewBestTime {
                        Text(loc.t("newRecordTime")).font(.system(size: 11, weight: .bold)).foregroundColor(Theme.ok)
                    }
                }
            }
            HStack {
                Text(loc.t("bestHints")).font(.system(size: 13)).foregroundColor(Theme.textDim)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(bestHints).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                    if isNewBestHints {
                        Text(loc.t("newRecordHints")).font(.system(size: 11, weight: .bold)).foregroundColor(Theme.ok)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgPanel2))
    }

    private func statBlock(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
            Text(label).font(.system(size: 11)).foregroundColor(Theme.textFaint)
        }
    }
}

/// Win modal for Challenge mode: shows level completed, star rating and
/// best-time delta, offering "Next Level" (always) and "Back to Levels".
struct ChallengeWinModalView: View {
    @EnvironmentObject var loc: Localization
    let level: Int
    let stars: Int
    let bestStars: Int
    let time: String
    let bestTime: String
    let isNewBestTime: Bool
    let unlockedNext: Bool
    let onNextLevel: () -> Void
    let onLevels: () -> Void

    var body: some View {
        ModalOverlay {
            Text("🎉").font(.system(size: 44))
            Text("\(loc.t("level")) \(level) \(loc.t("levelCompleteSuffix"))")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.text)

            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { i in
                    Text("★")
                        .font(.system(size: 32))
                        .foregroundColor(i <= stars ? Theme.accent : Theme.textFaint)
                }
            }

            if unlockedNext {
                Text(loc.t("levelUnlocked"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.ok)
            }

            VStack(spacing: 8) {
                HStack {
                    Text(loc.t("time")).font(.system(size: 13)).foregroundColor(Theme.textDim)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(time).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                        if isNewBestTime {
                            Text(loc.t("newRecordTime"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.ok)
                        }
                    }
                }
                HStack {
                    Text(loc.t("bestTime")).font(.system(size: 13)).foregroundColor(Theme.textDim)
                    Spacer()
                    Text(bestTime).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                }
                HStack {
                    Text(loc.t("starsLabel")).font(.system(size: 13)).foregroundColor(Theme.textDim)
                    Spacer()
                    Text("\(bestStars) / 3").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgPanel2))

            Button(loc.t("nextLevel"), action: onNextLevel).buttonStyle(PrimaryButtonStyle())
            Button(loc.t("backToLevels"), action: onLevels).buttonStyle(GhostButtonStyle())
        }
    }
}

struct ConfirmModalView: View {
    @EnvironmentObject var loc: Localization
    let title: String
    let message: String
    let onYes: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ModalOverlay {
            Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
            Text(message).font(.system(size: 14)).foregroundColor(Theme.textDim).multilineTextAlignment(.center)
            Button(loc.t("confirm"), action: onYes).buttonStyle(PrimaryButtonStyle())
            Button(loc.t("cancel"), action: onCancel).buttonStyle(GhostButtonStyle())
        }
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Theme.bgPanel2).overlay(Capsule().stroke(Theme.borderStrong, lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

func formattedTime(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d", total / 60, total % 60)
}
