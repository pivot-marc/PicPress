import AppKit
import SwiftUI

/// Eigenes Einstellungsfenster statt der SwiftUI-`Settings`-Szene,
/// damit es sich auch programmatisch öffnen lässt (erster Start,
/// erneutes Öffnen der App im Finder, Menü-Button).
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView()
                .environmentObject(AppState.shared)
                .environmentObject(AppState.shared.settings)
        )
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "PicPress – Einstellungen"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
}
