import SwiftUI

struct SudokuGridView: View {
    let cells: [SudokuCell]
    let selectedIndex: Int?
    let shakeTokens: [Int: Int]
    let onCellTap: (Int) -> Void

    private var selectedValue: Int? { selectedIndex.flatMap { cells[$0].value } }
    private var selectedRow: Int? { selectedIndex.map { $0 / 9 } }
    private var selectedCol: Int? { selectedIndex.map { $0 % 9 } }
    private var selectedBox: Int? { selectedIndex.map { cells[$0].boxIndex } }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { col in
                            let index = row * 9 + col
                            let cell = cells[index]
                            let isSelected = index == selectedIndex
                            let isPeer = (selectedRow == row || selectedCol == col || selectedBox == cell.boxIndex) && !isSelected
                            let isSameNumber = selectedValue != nil && cell.value == selectedValue && !isSelected

                            SudokuCellView(
                                cell: cell,
                                isSelected: isSelected,
                                isPeer: isPeer,
                                isSameNumber: isSameNumber,
                                shakeToken: shakeTokens[index] ?? 0,
                                thickRight: col == 2 || col == 5,
                                thickBottom: row == 2 || row == 5,
                                onTap: { onCellTap(index) }
                            )
                            .frame(width: side / 9, height: side / 9)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .background(Theme.bgPanel)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderStrong, lineWidth: 2))
            .cornerRadius(12)
            .clipped()
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct SudokuCellView: View {
    let cell: SudokuCell
    let isSelected: Bool
    let isPeer: Bool
    let isSameNumber: Bool
    let shakeToken: Int
    let thickRight: Bool
    let thickBottom: Bool
    let onTap: () -> Void

    @State private var shakeOffset: CGFloat = 0

    private var bg: Color {
        if cell.isConflict { return Theme.conflictBg }
        if isSelected { return Theme.selectedCellBg }
        if isSameNumber { return Theme.sameNumberHighlightBg }
        if isPeer { return Theme.peerHighlightBg }
        return Theme.bgPanel2
    }

    var body: some View {
        ZStack {
            Rectangle().fill(bg)
            if let value = cell.value {
                Text("\(value)")
                    .font(.system(size: 18, weight: cell.isGiven ? .bold : .semibold))
                    .foregroundColor(cell.isConflict ? Theme.conflictText : (cell.isGiven ? Theme.givenDigit : Theme.userDigit))
            } else if !cell.notes.isEmpty {
                NotesGridView(notes: cell.notes)
            }
        }
        .padding(.trailing, thickRight ? 1.5 : 0.25)
        .padding(.bottom, thickBottom ? 1.5 : 0.25)
        .padding(.leading, 0.25)
        .padding(.top, 0.25)
        .offset(x: shakeOffset)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onChange(of: shakeToken) { _ in
            guard shakeToken > 0 else { return }
            let anim = Animation.linear(duration: 0.06)
            withAnimation(anim) { shakeOffset = -4 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(anim) { shakeOffset = 4 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(anim) { shakeOffset = -3 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        withAnimation(anim) { shakeOffset = 0 }
                    }
                }
            }
        }
    }
}

private struct NotesGridView: View {
    let notes: Set<Int>

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3) { c in
                        let digit = r * 3 + c + 1
                        Text(notes.contains(digit) ? "\(digit)" : "")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Theme.noteText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(2)
    }
}
