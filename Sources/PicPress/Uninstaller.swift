import AppKit
import Foundation

/// Vollständige Selbst-Deinstallation:
/// Login-Item austragen, Einstellungen löschen, App in den Papierkorb, beenden.
@MainActor
enum Uninstaller {
    /// Zeigt die Sicherheitsabfrage und deinstalliert bei Bestätigung.
    static func confirmAndUninstall() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "PicPress wirklich deinstallieren?"
        alert.informativeText = "Der Start bei Anmeldung wird entfernt, alle Einstellungen werden gelöscht und die App wird in den Papierkorb gelegt."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Deinstallieren")
        alert.addButton(withTitle: "Abbrechen")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try uninstall()
            NSApp.terminate(nil)
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Deinstallation unvollständig"
            errorAlert.informativeText = "Die App konnte nicht in den Papierkorb gelegt werden: \(error.localizedDescription)\nBitte lösche PicPress.app manuell aus dem Programme-Ordner."
            errorAlert.alertStyle = .critical
            errorAlert.runModal()
        }
    }

    /// Führt alle Deinstallationsschritte aus (ohne Rückfrage und ohne die App
    /// zu beenden) — wird auch vom CLI-Flag `--uninstall` genutzt.
    static func uninstall() throws {
        // 1. Start bei Anmeldung austragen
        try? LoginItemManager.setEnabled(false)

        // 2. Einstellungen löschen
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }

        // 3. App-Bundle in den Papierkorb legen (funktioniert auch, während
        //    die App läuft — das Binary bleibt bis zum Beenden im Speicher)
        if AppState.runsFromAppBundle {
            try FileManager.default.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)
        }
    }
}
