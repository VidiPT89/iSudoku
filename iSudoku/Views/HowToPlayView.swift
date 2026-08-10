import SwiftUI

private struct MiniGrid: View {
    var highlightConflict = false
    var showNotes = false

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3) { r in
                HStack(spacing: 2) {
                    ForEach(0..<3) { c in
                        cell(r, c)
                    }
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgPanel2))
    }

    @ViewBuilder
    private func cell(_ r: Int, _ c: Int) -> some View {
        let isConflictCell = highlightConflict && ((r == 0 && c == 0) || (r == 0 && c == 2))
        RoundedRectangle(cornerRadius: 3)
            .fill(isConflictCell ? Theme.conflictBg : Theme.bgPanel)
            .frame(width: 20, height: 20)
            .overlay(
                Group {
                    if showNotes && r == 1 && c == 1 {
                        Text("1 2\n4 5").font(.system(size: 5)).foregroundColor(Theme.noteText)
                    } else if r == 1 && c == 1 {
                        Text(isConflictCell ? "" : "7")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isConflictCell ? Theme.conflictText : Theme.userDigit)
                    } else if isConflictCell {
                        Text("7").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.conflictText)
                    }
                }
            )
    }
}

struct HowToPlayView: View {
    @EnvironmentObject var loc: Localization
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Theme.text)
                            .padding(10)
                            .background(Circle().fill(Theme.bgPanel2))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(loc.t("htpTitle")).font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        Text(loc.t("htpIntro"))
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textDim)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(loc.t("htpRuleTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
                            Text(loc.t("htpRuleBody")).font(.system(size: 14)).foregroundColor(Theme.textDim)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(loc.t("htpGivenTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
                            Text(loc.t("htpGivenBody")).font(.system(size: 14)).foregroundColor(Theme.textDim)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(loc.t("htpConflictTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
                            HStack(alignment: .top, spacing: 16) {
                                Text(loc.t("htpConflictBody")).font(.system(size: 14)).foregroundColor(Theme.textDim)
                                MiniGrid(highlightConflict: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(loc.t("htpNotesTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
                            HStack(alignment: .top, spacing: 16) {
                                Text(loc.t("htpNotesBody")).font(.system(size: 14)).foregroundColor(Theme.textDim)
                                MiniGrid(showNotes: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(loc.t("htpToolsTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
                            toolRow(loc.t("hint"), loc.t("htpHintTool"))
                            toolRow(loc.t("undo"), loc.t("htpUndoTool"))
                        }
                    }
                    .padding(20)
                }

                Button(loc.t("htpCloseButton"), action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.bottom, 20)
            }
        }
    }

    private func toolRow(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.text)
            Text("— " + body).font(.system(size: 14)).foregroundColor(Theme.textDim)
        }
    }
}
