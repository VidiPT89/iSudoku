import SwiftUI

/// Technique Academy lesson list, in teaching order: each card shows the technique's tier, its
/// idea and how close the player is to mastering it, and the first unmastered one is flagged.
struct AcademyScreen: View {
    @EnvironmentObject var loc: Localization
    let progress: AcademyProgress
    let onBack: () -> Void
    let onPickLesson: (Lesson) -> Void

    var body: some View {
        ZStack {
            BackgroundGlow()

            VStack(spacing: 0) {
                HStack {
                    CircleIconButton(systemName: "chevron.left", label: loc.t("backToMenu"), action: onBack)
                    Text(loc.t("academy"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)

                ScrollView {
                    VStack(spacing: 12) {
                        Text(loc.t("academySubtitle"))
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textDim)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)

                        ForEach(Lesson.allCases, id: \.self) { lesson in
                            LessonCard(
                                lesson: lesson,
                                record: progress.record(lesson),
                                isNext: lesson == progress.recommended,
                                onTap: { onPickLesson(lesson) }
                            )
                        }
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct LessonCard: View {
    @EnvironmentObject var loc: Localization
    let lesson: Lesson
    let record: LessonRecord
    let isNext: Bool
    let onTap: () -> Void

    private var mastered: Bool { record.mastery >= AcademyProgress.masteryGoal }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(loc.t("lesson_\(lesson.rawValue)_Name"))
                        .font(.system(.headline))
                        .foregroundColor(Theme.text)
                    Text(loc.t("tier\(lesson.tier)").uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Theme.textFaint)
                    Spacer()
                    if mastered {
                        badge(loc.t("mastered"), color: Theme.ok)
                    } else if isNext {
                        badge(loc.t("nextUp"), color: Theme.accent)
                    }
                }
                Text(loc.t("lesson_\(lesson.rawValue)_Idea"))
                    .font(.system(.footnote))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Text(loc.t("masteryLabel"))
                        .font(.system(.caption2, weight: .medium))
                        .foregroundColor(Theme.textFaint)
                    ForEach(0..<AcademyProgress.masteryGoal, id: \.self) { i in
                        Circle()
                            .fill(i < record.mastery ? Theme.accent : Theme.bgPanel)
                            .overlay(Circle().stroke(Theme.borderStrong, lineWidth: 1))
                            .frame(width: 9, height: 9)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgPanel2))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isNext ? Theme.accent : Theme.border, lineWidth: isNext ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(loc.t("masteryLabel")) \(record.mastery)/\(AcademyProgress.masteryGoal)")
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.bg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }
}
