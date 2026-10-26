import Foundation
import Combine

enum Lang: String {
    case pt, en
}

/// Tiny map-backed localizer, defaulting to Portuguese and persisted via UserDefaults.
/// Published so SwiftUI recomposes automatically when the language toggles.
final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "isudoku-lang") }
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: "isudoku-lang"), let l = Lang(rawValue: stored) {
            lang = l
        } else {
            lang = .pt
        }
    }

    func toggle() {
        lang = lang == .pt ? .en : .pt
    }

    func t(_ key: String) -> String {
        strings[lang]?[key] ?? key
    }

    /// Hint panel text: the elimination steps, then either the clue (where to look) or, once
    /// revealed, the deduction that fills the cell. One sentence per line.
    func hintExplanation(_ hint: HintPlan) -> String {
        func fill(_ key: String, _ values: [String: String]) -> String {
            values.reduce(t(key)) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        }
        func line(_ unit: SudokuUnit) -> String { fill(unit.kind == .row ? "lineRow" : "lineCol", ["n": "\(unit.index + 1)"]) }
        func cellRef(_ i: Int) -> String { fill("cellRef", ["r": "\(i / 9 + 1)", "c": "\(i % 9 + 1)"]) }
        var lines = hint.eliminations.map { e -> String in
            switch e.kind {
            case .pointing: return fill("elimPointing", ["b": "\(e.source.index + 1)", "d": "\(e.digits[0])", "line": line(e.target)])
            case .claiming: return fill("elimClaiming", ["b": "\(e.target.index + 1)", "d": "\(e.digits[0])", "line": line(e.source)])
            case .pair:
                let ofKey = e.source.kind == .row ? "ofRow" : e.source.kind == .col ? "ofCol" : "ofBox"
                return fill("elimPair", ["cells": e.cells.map(cellRef).joined(separator: t("and")),
                                         "a": "\(e.digits[0])", "e": "\(e.digits[1])", "of": fill(ofKey, ["n": "\(e.source.index + 1)"])])
            }
        }
        let prefix = hint.revealed ? "hint" : "clue"
        let key: String
        switch hint.technique {
        case .hidden: key = prefix + (hint.unit?.kind == .box ? "HiddenBox" : hint.unit?.kind == .row ? "HiddenRow" : "HiddenCol")
        case .naked: key = prefix + "Naked"
        case .wrong: key = prefix + "Wrong"
        case .reveal: key = prefix + "Reveal"
        }
        lines.append(fill(key, ["r": "\(hint.index / 9 + 1)", "c": "\(hint.index % 9 + 1)", "d": "\(hint.digit)"]))
        if !hint.revealed { lines.append(t("clueNext")) }
        return lines.joined(separator: "\n")
    }

    private let strings: [Lang: [String: String]] = [
        .pt: [
            "mistakes": "Erros",
            "htpChallengeBody": "Cada número diferente da solução conta como um erro, mesmo sem conflito visível. Soma erros e dicas: 0 dá 3 estrelas, 1 a 3 dá 2 estrelas, 4 ou mais dá 1 estrela. O tempo não afeta as estrelas. Fica guardado o teu melhor resultado de cada nível.",
            "htpChallengeTitle": "Desafios e estrelas",
            "row": "Linha", "column": "Coluna", "emptyCell": "vazia", "fixedCell": "fixa", "conflictCell": "em conflito",
            "tapToContinue": "Toque para continuar",
            "developedBy": "Desenvolvido por",

            "menuTag": "PUZZLE DE LÓGICA",
            "menuSubtitle": "Preenche a grelha 9x9. Sem repetições em linhas, colunas ou blocos.",
            "play": "Jogar",
            "continueGame": "Continuar",
            "howToPlay": "Como Jogar",

            "difficultyLabel": "Dificuldade",
            "easy": "Fácil",
            "medium": "Médio",
            "hard": "Difícil",
            "expert": "Expert",

            "challenges": "Desafios",
            "challengesTitle": "Desafios",
            "challengesSubtitle": "Puzzles com menos pistas até ao nível expert. Repete níveis para melhorar as tuas estrelas.",
            "level": "Nível",
            "locked": "Bloqueado",
            "levelReached": "Nível",
            "starsLabel": "Estrelas",
            "showEarlier": "Ver níveis anteriores",
            "nextLevel": "Próximo Nível",
            "backToLevels": "Voltar aos Níveis",
            "levelUnlocked": "Novo nível desbloqueado!",
            "levelCompleteSuffix": "Completo!",

            "notes": "Notas",
            "erase": "Apagar",
            "newGame": "Novo Jogo",
            "hint": "Dica",
            "undo": "Anular",
            "time": "Tempo",
            "moves": "Jogadas",
            "hintsLeft": "Dicas",
            "noHintsLeft": "Sem mais dicas disponíveis.",
            "nothingToUndo": "Nada para anular.",
            "sound": "Som",
            "reveal": "Revelar",
            "lineRow": "linha {n}", "lineCol": "coluna {n}",
            "ofRow": "da linha {n}", "ofCol": "da coluna {n}", "ofBox": "do bloco {n}",
            "cellRef": "(linha {r}, coluna {c})", "and": " e ",
            "elimPointing": "No bloco {b}, o {d} só pode ficar na {line}, por isso sai do resto da {line}.",
            "elimClaiming": "Na {line}, o {d} só pode ficar no bloco {b}, por isso sai das outras casas desse bloco.",
            "elimPair": "As casas {cells} só aceitam o {a} e o {e}, por isso esses números saem das outras casas {of}.",
            "clueWrong": "Há um número errado na linha {r}.",
            "clueHiddenBox": "Olha para o bloco destacado: o {d} só tem uma casa possível.",
            "clueHiddenRow": "Olha para a linha {r}: o {d} só tem uma casa possível.",
            "clueHiddenCol": "Olha para a coluna {c}: o {d} só tem uma casa possível.",
            "clueNaked": "Na linha {r} há uma casa onde só cabe um número.",
            "clueReveal": "Não há dedução simples neste momento.",
            "clueNext": "Carrega em Revelar para preencher a casa (gasta uma dica).",
            "on": "ligado",
            "off": "desligado",
            "hintHiddenBox": "No bloco destacado, o {d} só cabe na linha {r}, coluna {c}.",
            "hintHiddenRow": "Na linha {r}, o {d} só cabe na coluna {c}.",
            "hintHiddenCol": "Na coluna {c}, o {d} só cabe na linha {r}.",
            "hintNaked": "Linha {r}, coluna {c}: só o {d} é possível. Os outros números já estão na mesma linha, coluna ou bloco.",
            "hintWrong": "Linha {r}, coluna {c} estava errada: a resposta é {d}.",
            "hintReveal": "Linha {r}, coluna {c}: não há dedução simples aqui de momento. A resposta é {d}.",

            "winTitle": "Grelha Completa!",
            "winSubtitle": "Resolveste o puzzle com sucesso.",
            "playAgain": "Jogar Novamente",
            "backToMenu": "Voltar ao Menu",
            "finalHints": "Dicas usadas",
            "bestTime": "Melhor Tempo",
            "bestHints": "Menos Dicas",
            "newRecordTime": "Novo recorde!",
            "newRecordHints": "Novo recorde!",

            "confirmRestartTitle": "Começar Novo Jogo?",
            "confirmRestartBody": "Vais perder o progresso atual. O novo puzzle mantém a dificuldade.",
            "confirm": "Confirmar",
            "cancel": "Cancelar",

            "htpTitle": "Como Jogar",
            "htpIntro": "O objetivo é preencher a grelha 9x9 com os números de 1 a 9.",
            "htpRuleTitle": "A Regra",
            "htpRuleBody": "Cada linha, cada coluna e cada bloco 3x3 tem de conter todos os números de 1 a 9, sem repetições.",
            "htpGivenTitle": "Números Fixos",
            "htpGivenBody": "Os números já preenchidos no início são fixos e não podem ser alterados. Os restantes são preenchidos por ti.",
            "htpConflictTitle": "Conflitos",
            "htpConflictBody": "Se colocares um número que já existe na mesma linha, coluna ou bloco, essas células ficam destacadas a vermelho.",
            "htpNotesTitle": "Notas",
            "htpNotesBody": "Marca candidatos nas casas vazias. Ao colocar um número, essa nota é removida da mesma linha, coluna e bloco. Desfazer também recupera essas notas.",
            "htpToolsTitle": "Ferramentas",
            "htpHintTool": "O primeiro toque dá uma pista grátis: onde olhar, sem preencher. O segundo (Revelar) preenche a casa e explica a dedução: um número errado primeiro; senão sozinhos, candidatos apontados, reclamados ou pares. Há 3, 4 ou 5 revelações por partida e uma usada continua a contar mesmo que desfaças a jogada.",
            "htpUndoTool": "Recupera o valor e as notas anteriores. Os últimos 200 movimentos ficam guardados ao sair e retomar. Erros e dicas usados continuam a contar.",
            "htpCloseButton": "Entendido",
        ],
        .en: [
            "mistakes": "Mistakes",
            "htpChallengeBody": "Each digit that differs from the solution counts as a mistake, even without a visible conflict. Add mistakes and hints: 0 earns 3 stars, 1 to 3 earns 2 stars, 4 or more earns 1 star. Time does not affect stars. Your best result for each level is kept.",
            "htpChallengeTitle": "Challenges and stars",
            "row": "Row", "column": "Column", "emptyCell": "empty", "fixedCell": "given", "conflictCell": "conflicting",
            "tapToContinue": "Tap to continue",
            "developedBy": "Developed by",

            "menuTag": "LOGIC PUZZLE",
            "menuSubtitle": "Fill the 9x9 grid. No repeats in any row, column or box.",
            "play": "Play",
            "continueGame": "Continue",
            "howToPlay": "How to Play",

            "difficultyLabel": "Difficulty",
            "easy": "Easy",
            "medium": "Medium",
            "hard": "Hard",
            "expert": "Expert",

            "challenges": "Challenges",
            "challengesTitle": "Challenges",
            "challengesSubtitle": "Puzzles with fewer clues up to expert level. Replay levels to improve your stars.",
            "level": "Level",
            "locked": "Locked",
            "levelReached": "Level",
            "starsLabel": "Stars",
            "showEarlier": "Show earlier levels",
            "nextLevel": "Next Level",
            "backToLevels": "Back to Levels",
            "levelUnlocked": "New level unlocked!",
            "levelCompleteSuffix": "Complete!",

            "notes": "Notes",
            "erase": "Erase",
            "newGame": "New Game",
            "hint": "Hint",
            "undo": "Undo",
            "time": "Time",
            "moves": "Moves",
            "hintsLeft": "Hints",
            "noHintsLeft": "No more hints available.",
            "nothingToUndo": "Nothing to undo.",
            "sound": "Sound",
            "reveal": "Reveal",
            "lineRow": "row {n}", "lineCol": "column {n}",
            "ofRow": "row {n}", "ofCol": "column {n}", "ofBox": "box {n}",
            "cellRef": "(row {r}, column {c})", "and": " and ",
            "elimPointing": "In box {b}, {d} can only go in {line}, so it leaves the rest of {line}.",
            "elimClaiming": "In {line}, {d} can only go in box {b}, so it leaves the other cells of that box.",
            "elimPair": "Cells {cells} only take {a} and {e}, so those digits leave the other cells of {of}.",
            "clueWrong": "There is a wrong digit in row {r}.",
            "clueHiddenBox": "Look at the highlighted box: {d} has only one possible cell.",
            "clueHiddenRow": "Look at row {r}: {d} has only one possible cell.",
            "clueHiddenCol": "Look at column {c}: {d} has only one possible cell.",
            "clueNaked": "Row {r} has a cell where only one digit fits.",
            "clueReveal": "No simple deduction applies right now.",
            "clueNext": "Press Reveal to fill the cell in (uses a hint).",
            "on": "on",
            "off": "off",
            "hintHiddenBox": "In the highlighted box, {d} only fits in row {r}, column {c}.",
            "hintHiddenRow": "In row {r}, {d} only fits in column {c}.",
            "hintHiddenCol": "In column {c}, {d} only fits in row {r}.",
            "hintNaked": "Row {r}, column {c}: only {d} is possible. Every other digit is already in its row, column or box.",
            "hintWrong": "Row {r}, column {c} was wrong: the answer is {d}.",
            "hintReveal": "Row {r}, column {c}: no simple deduction applies here right now. The answer is {d}.",

            "winTitle": "Grid Complete!",
            "winSubtitle": "You solved the puzzle.",
            "playAgain": "Play Again",
            "backToMenu": "Back to Menu",
            "finalHints": "Hints used",
            "bestTime": "Best Time",
            "bestHints": "Fewest Hints",
            "newRecordTime": "New record!",
            "newRecordHints": "New record!",

            "confirmRestartTitle": "Start a New Game?",
            "confirmRestartBody": "You'll lose your current progress. The new puzzle keeps the same difficulty.",
            "confirm": "Confirm",
            "cancel": "Cancel",

            "htpTitle": "How to Play",
            "htpIntro": "The goal is to fill the 9x9 grid with the digits 1 through 9.",
            "htpRuleTitle": "The Rule",
            "htpRuleBody": "Every row, every column and every 3x3 box must contain each digit from 1 to 9 exactly once.",
            "htpGivenTitle": "Given Numbers",
            "htpGivenBody": "Numbers already filled in at the start are fixed and cannot be changed. The rest are yours to fill.",
            "htpConflictTitle": "Conflicts",
            "htpConflictBody": "If you place a number that already exists in the same row, column or box, those cells are highlighted in red.",
            "htpNotesTitle": "Notes",
            "htpNotesBody": "Mark candidates in empty cells. Placing a digit removes that note from its row, column and box. Undo also restores those notes.",
            "htpToolsTitle": "Tools",
            "htpHintTool": "The first tap gives a free clue: where to look, without filling anything. The second (Reveal) fills the cell and explains the deduction: a wrong digit first; otherwise singles, pointing or claiming candidates, or pairs. Each game has 3, 4 or 5 reveals and a used one still counts even if you undo the move.",
            "htpUndoTool": "Restores the previous value and notes. The last 200 moves are saved when you leave and resume. Mistakes and used hints still count.",
            "htpCloseButton": "Got It",
        ],
    ]
}
