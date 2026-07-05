import Foundation
import ServiceManagement

/// „Bei Anmeldung starten" über SMAppService — der native Ersatz für
/// manuell gepflegte LaunchAgent-Plists. Funktioniert nur, wenn die App
/// aus einem richtigen .app-Bundle läuft (nicht über `swift run`).
@MainActor
enum LoginItemManager {
    static var isAvailable: Bool {
        AppState.runsFromAppBundle
    }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard isAvailable else { return }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
