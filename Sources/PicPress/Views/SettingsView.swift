import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsStore
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            watchSection
            processingSection
            outputSection
            systemSection
            uninstallSection
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            launchAtLogin = LoginItemManager.isEnabled
        }
    }

    private var watchSection: some View {
        Section("Überwachung") {
            Toggle("Ordner überwachen", isOn: $settings.watcherEnabled)

            LabeledContent("Überwachter Ordner") {
                HStack {
                    Text(abbreviated(settings.watchFolderPath))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Button("Auswählen…") {
                        if let url = Self.chooseFolder(startingAt: settings.watchFolderPath) {
                            settings.watchFolderPath = url.path
                        }
                    }
                }
            }
        }
    }

    private var processingSection: some View {
        Section("Verarbeitung") {
            Picker("Ausgabeformat", selection: $settings.outputFormat) {
                ForEach(OutputFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }

            VStack(alignment: .leading) {
                Slider(value: $settings.quality, in: 10...100, step: 5) {
                    Text("Qualität: \(Int(settings.quality)) %")
                }
                .disabled(!settings.outputFormat.supportsQuality)
                if !settings.outputFormat.supportsQuality {
                    Text("PNG ist verlustfrei — Qualität wird ignoriert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Maximale Breite") {
                HStack(spacing: 4) {
                    TextField("", value: $settings.targetWidth, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                    Text("px")
                        .foregroundStyle(.secondary)
                    Stepper("", value: $settings.targetWidth, in: 0...10000, step: 100)
                        .labelsHidden()
                }
            }
            Text("Breitere Bilder werden proportional verkleinert. 0 = nie verkleinern.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Original nach Konvertierung in den Papierkorb legen", isOn: $settings.deleteOriginal)
        }
    }

    private var outputSection: some View {
        Section("Ausgabe") {
            Picker("Zielordner", selection: $settings.outputMode) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            if settings.outputMode == .customFolder {
                LabeledContent("Eigener Ordner") {
                    HStack {
                        Text(settings.customOutputFolderPath.isEmpty
                             ? "Kein Ordner gewählt"
                             : abbreviated(settings.customOutputFolderPath))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Auswählen…") {
                            if let url = Self.chooseFolder(startingAt: settings.customOutputFolderPath) {
                                settings.customOutputFolderPath = url.path
                            }
                        }
                    }
                }
            }
        }
    }

    private var systemSection: some View {
        Section("System") {
            Toggle("Bei Anmeldung starten", isOn: $launchAtLogin)
                .disabled(!LoginItemManager.isAvailable)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        try LoginItemManager.setEnabled(newValue)
                    } catch {
                        launchAtLogin = LoginItemManager.isEnabled
                    }
                }
            if !LoginItemManager.isAvailable {
                Text("Nur verfügbar, wenn die App aus dem Programme-Ordner läuft.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Benachrichtigung nach jeder Konvertierung", isOn: $settings.showNotifications)
                .onChange(of: settings.showNotifications) { _, newValue in
                    if newValue {
                        AppState.requestNotificationPermission()
                    }
                }
        }
    }

    private var uninstallSection: some View {
        Section {
            HStack {
                Button("PicPress deinstallieren…", role: .destructive) {
                    Uninstaller.confirmAndUninstall()
                }
                .disabled(!AppState.runsFromAppBundle)
                Spacer()
            }
            Text("Entfernt den Start bei Anmeldung, löscht alle Einstellungen und legt die App in den Papierkorb.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func abbreviated(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    @MainActor
    private static func chooseFolder(startingAt path: String?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Auswählen"
        if let path, !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}
