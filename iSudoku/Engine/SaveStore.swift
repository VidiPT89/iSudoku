import Foundation

/// Persists a single in-progress game so the player can resume exactly where they left off
/// ("Continue" on the main menu).
enum SaveStore {
    private static let key = "isudoku-save"

    static func save(_ engine: GameEngine) {
        guard let data = try? JSONEncoder().encode(engine.makeSnapshot()) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> SudokuSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SudokuSnapshot.self, from: data)
    }

    static func hasSave() -> Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
