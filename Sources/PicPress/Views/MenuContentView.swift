import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            statusSection
            Divider()
            recentSection
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .foregroundStyle(.tint)
            Text("PicPress")
                .font(.headline)
            Spacer()
            Toggle("", isOn: $settings.watcherEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let error = appState.lastError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(3)
        } else if appState.isWatching {
            Label {
                Text("Überwacht: \(URL(fileURLWithPath: settings.watchFolderPath).lastPathComponent)")
            } icon: {
                Circle().fill(.green).frame(width: 8, height: 8)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Label {
                Text("Pausiert")
            } icon: {
                Circle().fill(.gray).frame(width: 8, height: 8)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if appState.totalProcessed > 0 {
            Text("\(appState.totalProcessed) Bilder verarbeitet · \(ByteCountFormatter.string(fromByteCount: appState.totalBytesSaved, countStyle: .file)) gespart")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if appState.recentResults.isEmpty {
            Text("Noch keine Bilder verarbeitet")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(appState.recentResults.prefix(5)) { result in
                    RecentResultRow(result: result)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Einstellungen…") {
                SettingsWindowController.shared.show()
            }
            Spacer()
            Button("Beenden") {
                NSApp.terminate(nil)
            }
        }
        .controlSize(.small)
    }
}

private struct RecentResultRow: View {
    let result: ProcessingResult

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(result.outputURL.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(ByteCountFormatter.string(fromByteCount: result.sourceBytes, countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: result.outputBytes, countStyle: .file)) (−\(result.savingsPercent) %)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Im Finder anzeigen")
    }
}
