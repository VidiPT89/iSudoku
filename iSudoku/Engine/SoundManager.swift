#if os(macOS)
import AppKit
#else
import AudioToolbox
#endif

/// Sound feedback for digit entry / conflict / hint / win.
///
/// The project ships no custom audio assets, so each platform uses its built-in UI sounds:
/// AudioToolbox system sound IDs on iOS (which respect the silent switch) and the named
/// system sounds from /System/Library/Sounds on macOS, where the iOS IDs do not exist.
/// If real sound design assets are added later (e.g. iSudoku/Sounds/*.caf), swap this for
/// AVAudioPlayer — the call sites in GameView would not need to change.
enum SoundManager {
    private enum Effect {
        case digitEnter, conflict, hint, win

        #if os(macOS)
        var name: NSSound.Name {
            switch self {
            case .digitEnter: return "Tink"
            case .conflict: return "Basso"
            case .hint: return "Pop"
            case .win: return "Glass"
            }
        }
        #else
        var id: SystemSoundID {
            switch self {
            case .digitEnter: return 1104 // "Tock" — short, unobtrusive tap
            case .conflict: return 1053   // low negative buzz
            case .hint: return 1111       // short positive click
            case .win: return 1025        // more elaborate multi-tone sound
            }
        }
        #endif
    }

    static func digitEnter() { play(.digitEnter) }
    static func conflict() { play(.conflict) }
    static func hint() { play(.hint) }
    static func win() { play(.win) }

    private static func play(_ effect: Effect) {
        #if os(macOS)
        guard let sound = NSSound(named: effect.name) else { return }
        sound.stop()
        sound.play()
        #else
        AudioServicesPlaySystemSound(effect.id)
        #endif
    }
}
