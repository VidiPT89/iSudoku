import SwiftUI

@main
struct iSudokuApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 720)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
