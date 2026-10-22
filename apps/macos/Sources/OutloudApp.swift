import SwiftUI

/// The menu bar app (ADR 0004).
@main
struct OutloudApp: App {
    var body: some Scene {
        MenuBarExtra("Outloud", systemImage: "waveform") {
            Button("Quit Outloud") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
