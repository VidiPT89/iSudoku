import SwiftUI

struct NumberPadView: View {
    let remainingCounts: [Int]
    let notesMode: Bool
    let onDigit: (Int) -> Void
    let onErase: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { digit in
                key(digit)
            }
            Button(action: onErase) {
                Image(systemName: "delete.left")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textDim)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(0.75, contentMode: .fit)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel2))
            }
            .buttonStyle(.plain)
        }
    }

    private func key(_ digit: Int) -> some View {
        let disabled = !notesMode && remainingCounts[digit - 1] <= 0
        return Button(action: { onDigit(digit) }) {
            Text("\(digit)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(disabled ? Theme.textFaint : Theme.text)
                .frame(maxWidth: .infinity)
                .aspectRatio(0.75, contentMode: .fit)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel2))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
