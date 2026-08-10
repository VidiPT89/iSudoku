# 🔢 iSudoku — Sudoku for macOS & iOS

> A native SwiftUI Sudoku app for macOS and iOS — uniquely-solvable puzzles, pencil-mark notes, limited hints and a local leaderboard.

"iSudoku" is a from-scratch Swift implementation built around a single guarantee: **every generated puzzle has exactly one solution**. There's no puzzle database — each game is freshly generated on-device by filling a full grid and carving it back down while checking uniqueness at every step. One codebase, two native targets, both built with SwiftUI.

## 📦 What's Inside

- 🎚️ Three difficulty levels — **Easy** (40–45 clues), **Medium** (32–36 clues) and **Hard** (26–30 clues)
- ✅ Uniquely-solvable puzzles — clues are removed one at a time, keeping each removal only if the puzzle still solves to exactly one grid
- ✏️ Pencil-mark notes mode — jot down candidate digits in a cell instead of committing a final value
- 🚫 Live conflict detection — placing a digit that already exists in the same row, column or 3x3 box highlights every conflicting cell
- 💡 Limited hints per game (3/4/5 by difficulty) that reveal the correct value for the selected cell — or a random incorrect one if nothing's selected — and ↩️ unlimited undo
- 🎬 Smooth SwiftUI animations on digit entry and hint reveal
- 💾 Autosaves mid-game, with a "Continue Game" option from the main menu
- 🏆 A local best-time / fewest-hints leaderboard per difficulty, stored on-device (no backend), shown after a win
- 🔊 Sound feedback on digit entry, conflicts and winning (see [Sound](#-sound) below)
- 📖 An in-app "How to Play" guide covering the rule, given cells, conflicts, notes and the hint/undo tools
- 🇵🇹 🇬🇧 One-click language toggle between European Portuguese and English, remembered between visits
- 🖥️ 📱 One codebase, two native targets — macOS and iOS/iPadOS, both built with SwiftUI

## 🛠️ Tech Stack

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0066CC?style=flat&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-16%2B-000000?style=flat&logo=apple&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-13%2B-000000?style=flat&logo=apple&logoColor=white)
![xcodegen](https://img.shields.io/badge/xcodegen-project.yml-blue?style=flat)
![XCTest](https://img.shields.io/badge/XCTest-unit%20tests-blue?style=flat)

## 🏗️ Project Structure

```
iSudoku/
├── project.yml               # xcodegen config — iSudoku-iOS, iSudoku-macOS and iSudokuTests targets
├── iSudoku/                   # Shared SwiftUI source for both app targets
│   ├── iSudokuApp.swift        # App entry point
│   ├── Theme.swift             # ividi.dev-matched color tokens
│   ├── Localization.swift      # PT/EN strings and language persistence
│   ├── Models/
│   │   └── SudokuCell.swift     # Cell model + difficulty clue/hint tiers
│   ├── Engine/
│   │   ├── SudokuGenerator.swift # Randomized full-grid fill + hole digging
│   │   ├── SudokuSolver.swift     # MRV backtracking solver, capped solution counter, conflict scan
│   │   ├── GameEngine.swift        # Board state, dispatch results, undo stack, hints
│   │   ├── SaveStore.swift          # Mid-game autosave/restore (UserDefaults)
│   │   ├── Leaderboard.swift         # Local best time/hints per difficulty (UserDefaults)
│   │   └── SoundManager.swift         # Digit entry / conflict / win sound feedback
│   ├── Views/
│   │   ├── RootView.swift        # Screen router
│   │   ├── SplashView.swift       # Animated intro with developer credit
│   │   ├── MainMenuView.swift      # Menu, difficulty picker, language toggle
│   │   ├── HowToPlayView.swift      # Rules guide with a visual grid diagram
│   │   ├── GameView.swift            # Board screen, stats, actions, modals
│   │   ├── SudokuGridView.swift       # 9x9 grid rendering, cell/box borders, highlighting
│   │   ├── NumberPadView.swift         # Digit entry pad + erase
│   │   ├── Modals.swift                 # Win / confirm modals + leaderboard block
│   │   └── BackgroundGlow.swift          # Shared theme components
│   └── Assets.xcassets/          # App icon (all iOS/macOS sizes) + accent color
├── iSudokuTests/              # XCTest unit tests (generator, solver, engine)
├── LICENSE
└── README.md
```

## ⚙️ Game Mechanics

### Generating a uniquely-solvable puzzle
```
1. Fill an empty 9x9 grid completely via randomized backtracking
   (shuffled digit order at each cell, row/col/box legality check)

2. Dig holes: shuffle cell order, then for each cell —
     - tentatively clear it
     - re-solve the puzzle with a capped counter (stop early at 2 solutions)
     - keep the removal only if the count is still exactly 1
     - otherwise put the digit back
   stop once the difficulty's minimum clue count is reached

3. The solver used for both digging and hints is a single MRV
   (minimum-remaining-values) backtracker: always branch on the
   emptiest cell first, so contradictions surface almost immediately
```

### Hints & conflicts
```
Hint: reveals solution[selectedCell] if that cell is empty or wrong;
      otherwise picks a random cell that still needs fixing. Capped
      per game by difficulty (Easy 3 / Medium 4 / Hard 5).

Conflicts: recomputed from scratch after every move — for each row,
      column and 3x3 box, any digit appearing more than once flags
      every cell holding it. Win = grid full AND zero conflicts.
```

## 🚀 How to Run

```bash
# 1. Clone the repository
git clone https://github.com/VidiPT89/iSudoku.git
cd iSudoku

# 2. Generate the Xcode project (requires xcodegen: brew install xcodegen)
xcodegen generate

# 3. Open in Xcode and run either scheme
open iSudoku.xcodeproj
```

Pick the **iSudoku-iOS** scheme for iPhone/iPad (Simulator or device) or **iSudoku-macOS** for a native Mac app. Both targets share the exact same SwiftUI source. To run the unit tests, select the **iSudokuTests** target (or `Product > Test` / `xcodebuild test`) from either app scheme.

## 🔊 Sound

Digit entry, conflict and win feedback use `AudioServicesPlaySystemSound` (AudioToolbox) as a placeholder, since the project ships no custom audio assets yet — see the comment in `SoundManager.swift` for how to swap in real `.caf`/`.wav` files via `AVAudioPlayer` later.

## 📝 Notes

- Given (fixed) cells are set once at generation time and can never be edited or cleared, only the cells you fill in yourself
- Correcting a wrong entry counts as a valid hint target, not just filling in a blank cell
- Undo restores both the previous value and the previous notes for a cell, and un-spends a hint if the move it's undoing was one
- Language, in-progress games and the local leaderboard are all stored locally via `UserDefaults`, so they persist between visits
- This is an independent Swift codebase, part of a small triplet of from-scratch Sudoku implementations across Android, iOS/macOS and the web — no code is shared between them

---

Developed by **David Arsénio Martins** — *"Vidi"*
