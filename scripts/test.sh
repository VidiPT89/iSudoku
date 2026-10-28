#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/isudoku-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
swiftc -O -module-cache-path "$test_dir/modules" iSudoku/Models/SudokuCell.swift iSudoku/Engine/Challenge.swift Tests/ChallengeMath.swift -o "$test_dir/challenge"
"$test_dir/challenge"
swiftc -O -module-cache-path "$test_dir/modules" iSudoku/Models/SudokuCell.swift iSudoku/Engine/Challenge.swift iSudoku/Engine/SudokuSolver.swift iSudoku/Engine/Techniques.swift iSudoku/Engine/SudokuGenerator.swift iSudoku/Engine/GameEngine.swift iSudoku/Localization.swift iSudoku/LocalizationAcademy.swift iSudoku/Engine/SoundManager.swift Tests/EngineTests.swift -o "$test_dir/engine"
"$test_dir/engine"
swiftc -O -module-cache-path "$test_dir/modules" iSudoku/Models/SudokuCell.swift iSudoku/Engine/Challenge.swift iSudoku/Engine/SudokuSolver.swift iSudoku/Engine/Techniques.swift iSudoku/Engine/SudokuGenerator.swift iSudoku/Engine/Academy.swift iSudoku/Localization.swift iSudoku/LocalizationAcademy.swift Tests/AcademyTests.swift -o "$test_dir/academy"
"$test_dir/academy"
