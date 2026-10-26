import SwiftUI

struct NumberPadView: View {
    @EnvironmentObject var loc: Localization
    let remainingCounts: [Int]
    let notesMode: Bool
    let onDigit: (Int) -> Void
    let onErase: () -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(1...9, id: \.self) { digit in
                key(digit)
            }
            Button(action: onErase) {
                Image(systemName: "delete.left")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc.t("erase"))
        }
    }

    private func key(_ digit: Int) -> some View {
        let disabled = !notesMode && remainingCounts[digit - 1] <= 0
        return Button(action: { onDigit(digit) }) {
            Text("\(digit)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(disabled ? Theme.textFaint : Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel2))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
