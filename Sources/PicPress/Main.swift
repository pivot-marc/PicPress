import SwiftUI
import AppKit

@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--process") {
            CommandLineRunner.run()
        } else {
            PicPressApp.main()
        }
    }
}

struct PicPressApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppState.shared.start()

            // Beim allerersten Start das Einstellungsfenster zeigen —
            // sonst „passiert" für den Nutzer sichtbar nichts.
            let defaults = UserDefaults.standard
            if !defaults.bool(forKey: "hasLaunchedBefore") {
                defaults.set(true, forKey: "hasLaunchedBefore")
                SettingsWindowController.shared.show()
            }
        }
    }

    /// Wird die laufende App erneut geöffnet (Doppelklick im Finder,
    /// Launchpad), öffnet sich das Einstellungsfenster als sichtbares Feedback.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
        return true
    }
}
