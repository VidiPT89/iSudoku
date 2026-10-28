# 🔢 iSudoku — Sudoku for macOS & iOS

> A native SwiftUI Sudoku app for macOS and iOS — uniquely-solvable puzzles, pencil-mark notes, limited hints and a local leaderboard.

"iSudoku" is a from-scratch Swift implementation built around a single guarantee: **every generated puzzle has exactly one solution**. There's no puzzle database — each game is freshly generated on-device by filling a full grid and carving it back down while checking uniqueness at every step. One codebase, two native targets, both built with SwiftUI.

## 📦 What's Inside

- 🎚️ Three difficulty levels — **Easy** (target: 40 clues), **Medium** (target: 32) and **Hard** (target: 26)
- ✅ Uniquely-solvable puzzles — clues are removed one at a time, keeping each removal only if the puzzle still solves to exactly one grid
- ✏️ Pencil-mark notes mode — jot down candidate digits in a cell instead of committing a final value
- 🚫 Live conflict detection — placing a digit that already exists in the same row, column or 3x3 box highlights every conflicting cell
- 💡 Two-step teaching hints: the first tap gives a free **clue** — where to look, without filling anything; the second tap (**Reveal**, 3/4/5 per game by difficulty) fills the cell and explains the deduction. A wrong digit is fixed first; otherwise the hint uses the simplest technique that works — a single (only one cell for a digit in a box/row/column, or only one digit for a cell), exposed when needed by **pointing** or **claiming** candidates, a **naked pair** or, the hardest, an **X-Wing** — and shows only the elimination steps that single actually needs
- 🎓 **Technique Academy** — six lessons (hidden single, naked single, pointing, claiming, naked pair, X-Wing), each drilled on positions taken from freshly generated puzzles with every candidate shown. Place the single or pick a candidate the technique removes; any valid instance on the board counts, misses get a specific explanation, "Show me" reveals one with the pattern highlighted and the removed candidates struck through. Drills solved first try build a 5-step mastery meter per technique, and the lesson list flags the next one to learn
- 🔗 Hints link to practice — when a hint uses a technique, "Practise this technique" opens that Academy lesson and Back returns to the game
- 🧠 Difficulty graded by human technique, never by guessing: Easy and Medium are solvable with singles alone; Hard always needs pointing/claiming candidates or naked pairs, and those are always enough; expert challenge levels are always solvable by logic up to X-Wing
- ↩️ Undo for the last 200 moves, including after resuming a saved game
- 🎬 Smooth SwiftUI animations on digit entry and hint reveal
- 💾 Autosaves mid-game, with a "Continue Game" option from the main menu
- 🏆 A local best-time / fewest-hints leaderboard per difficulty, stored on-device (no backend), shown after a win
- 🔊 Sound feedback on digit entry, conflicts, hints and winning, with an on/off toggle in the game header (see [Sound](#-sound) below)
- ⌨️ Hardware keyboard support on Mac and iPad — digits 1-9, Delete to erase, arrow keys to move, N for notes, ⌘Z to undo
- 📖 An in-app "How to Play" guide covering the rule, given cells, conflicts, notes and the hint/undo tools
- 🇵🇹 🇬🇧 One-click language toggle between European Portuguese and English, remembered between visits
- 🖥️ 📱 One codebase, two native targets — macOS and iOS/iPadOS, both built with SwiftUI

## 🛠️ Tech Stack

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0066CC?style=flat&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-16%2B-000000?style=flat&logo=apple&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-13%2B-000000?style=flat&logo=apple&logoColor=white)
![xcodegen](https://img.shields.io/badge/xcodegen-project.yml-blue?style=flat)
![Tests](https://img.shields.io/badge/Swift-regression%20tests-blue?style=flat)

## 🏗️ Project Structure

```
iSudoku/
├── project.yml               # xcodegen config — iSudoku-iOS and iSudoku-macOS targets
├── iSudoku/                   # Shared SwiftUI source for both app targets
│   ├── iSudokuApp.swift        # App entry point
│   ├── Theme.swift             # ividi.dev-matched color tokens
│   ├── Localization.swift      # PT/EN strings and language persistence
│   ├── Models/
│   │   └── SudokuCell.swift     # Cell model + difficulty clue/hint tiers
│   ├── Engine/
│   │   ├── SudokuGenerator.swift # Randomized full-grid fill + hole digging
│   │   ├── SudokuSolver.swift     # Bitmask MRV solution counter and conflict scan
│   │   ├── Techniques.swift       # Human techniques: singles, pointing/claiming, naked pairs, X-Wing, grading
│   │   ├── Academy.swift          # Lessons, drill generation/checking, mastery progress (UserDefaults)
│   │   ├── GameEngine.swift        # Board state, dispatch results, undo stack, hints
│   │   ├── SaveStore.swift          # Mid-game autosave/restore (UserDefaults)
│   │   ├── Leaderboard.swift         # Local best time/hints per difficulty (UserDefaults)
│   │   └── SoundManager.swift         # Digit / conflict / hint / win sounds and the on/off preference
│   ├── Views/
│   │   ├── RootView.swift        # Screen router
│   │   ├── SplashView.swift       # Animated intro with developer credit
│   │   ├── MainMenuView.swift      # Menu, difficulty picker, language toggle
│   │   ├── HowToPlayView.swift      # Rules guide with a visual grid diagram
│   │   ├── GameView.swift            # Board screen, stats, actions, modals
│   │   ├── AcademyScreen.swift        # Lesson list with tiers and mastery
│   │   ├── LessonDrillView.swift      # One lesson: idea, drill board, feedback
│   │   ├── SudokuGridView.swift       # 9x9 grid rendering, cell/box borders, highlighting
│   │   ├── NumberPadView.swift         # Digit entry pad + erase
│   │   ├── Modals.swift                 # Win / confirm modals + leaderboard block
│   │   └── BackgroundGlow.swift          # Shared theme components
│   └── Assets.xcassets/          # App icon (all iOS/macOS sizes) + accent color
├── Tests/                     # Executable regression suites
├── scripts/test.sh           # Compiles and runs the Swift suites
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
   stop once the difficulty's target clue count is reached; a dig that
   gets stuck above the target is retried (up to 12 times) and the
   sparsest puzzle is kept. Removals must also keep the puzzle solvable by
   human techniques: singles only at 32+ clues (Easy, Medium), singles +
   pointing/claiming/naked pairs at 26-31 (Hard — which is retried until
   singles alone are not enough), and all of those plus X-Wing below 26
   (expert levels — retried for a puzzle that needs eliminations, and for
   one that needs X-Wing within a bounded budget, since those are rare)

3. The uniqueness check is a bitmask MRV (minimum-remaining-values)
   backtracker: row/column/box digits live in 9-bit masks and the search
   always branches on the emptiest cell first, so even expert grids are
   generated in milliseconds. Hints never re-solve — they read the
   cached solution grid
```

### Hints & conflicts
```
Hint: plans the selected cell (if empty or wrong), else any wrong
      entry, else the easiest single on the board (box, then row,
      column, then naked single), applying eliminations only when no
      single exists and pruning the chain to the steps it needs —
      reasoning only from correct digits. First tap: free clue. Second
      tap: reveal + explanation, capped per game (Easy 3 / Medium 4 /
      Hard 5).

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

Pick the **iSudoku-iOS** scheme for iPhone/iPad (Simulator or device) or **iSudoku-macOS** for a native Mac app. Both targets share the exact same SwiftUI source. Run the regression suites with `./scripts/test.sh` (requires the Xcode command-line tools). There is no XCTest target.

## 🔊 Sound

Digit entry, conflict, hint and win feedback use built-in system sounds, since the project ships no custom audio assets yet: `AudioServicesPlaySystemSound` (AudioToolbox) on iOS and named `NSSound`s on macOS. The speaker button in the game header turns them off (stored in `UserDefaults`) — see the comment in `SoundManager.swift` for how to swap in real `.caf`/`.wav` files via `AVAudioPlayer` later.

## 📝 Notes

- Given (fixed) cells are set once at generation time and can never be edited or cleared, only the cells you fill in yourself
- Correcting a wrong entry counts as a valid hint target, not just filling in a blank cell
- Undo restores the previous value and all affected notes. Used hints are never refunded, and mistakes remain counted
- Language, in-progress games and the local leaderboard are all stored locally via `UserDefaults`, so they persist between visits
- This is an independent Swift codebase, part of a pair of from-scratch Sudoku implementations for iOS/macOS and the web — no code is shared between the native and web apps

---

Developed by **David Arsénio Martins** — *"Vidi"*

## Verification and behaviour (2026-10-26)

- Challenge mode progressively reduces the target to 23 clues and awards 1–3 stars based on mistakes and hints. A generator may retain more clues to preserve a unique solution; clue count alone is not a human difficulty rating.
- The ↻ button starts a new puzzle at the same difficulty (or the same challenge level) after confirmation. Time pauses outside active play, during that confirmation and after victory.
- Invalid saved games are rejected safely; completed games are not offered as resumable games.
- Undo history is saved for up to 200 moves and restored with the game. Older saves without history remain compatible.
- The Android implementation was retired at the owner's request.

### Gameplay review (2026-10-26, second pass)

Placing a digit automatically removes that candidate from peer notes. Undo restores all affected notes, including after a save/reload. Completed boards cannot be edited after a result is recorded.

Challenge mistakes are visible during play. Stars use mistakes plus hints: 0 = 3 stars, 1–3 = 2 stars, 4+ = 1 star. Undo does not erase mistakes or refund hints. The guide explains this in Portuguese and English.
