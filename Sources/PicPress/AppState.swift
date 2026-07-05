import Foundation
import Combine
import UserNotifications
import os

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let settings = SettingsStore()

    @Published private(set) var recentResults: [ProcessingResult] = []
    @Published private(set) var isWatching = false
    @Published private(set) var lastError: String?
    @Published private(set) var totalProcessed = 0
    @Published private(set) var totalBytesSaved: Int64 = 0

    private static let logger = Logger(subsystem: "com.picpress.app", category: "processing")

    private var watcher: FolderWatcher?
    private var watchedPath: String?
    private let ignoreList = IgnoreList()
    private let processingQueue = DispatchQueue(label: "com.picpress.app.processing", qos: .utility)
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Watcher neu aufsetzen, sobald sich relevante Einstellungen ändern.
        settings.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshWatcher()
            }
            .store(in: &cancellables)
    }

    func start() {
        refreshWatcher()
    }

    private func refreshWatcher() {
        let desiredPath = settings.watcherEnabled ? settings.watchFolderPath : nil

        guard desiredPath != watchedPath || (desiredPath != nil && watcher == nil) else { return }

        watcher?.stop()
        watcher = nil
        isWatching = false
        watchedPath = desiredPath

        guard let path = desiredPath else { return }

        let url = URL(fileURLWithPath: path, isDirectory: true)
        let newWatcher = FolderWatcher(directoryURL: url) { urls in
            Task { @MainActor in
                AppState.shared.enqueue(urls)
            }
        }

        do {
            try newWatcher.start()
            watcher = newWatcher
            isWatching = true
            lastError = nil
            Self.logger.info("Überwache Ordner: \(path, privacy: .public)")
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("Watcher-Start fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func enqueue(_ urls: [URL]) {
        let config = settings.processingConfig
        let notify = settings.showNotifications

        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard !ImageProcessor.partialDownloadExtensions.contains(ext) else { continue }
            guard ImageProcessor.isSupportedImage(url) else { continue }
            guard !ignoreList.contains(url.path) else { continue }

            let ignoreList = self.ignoreList
            processingQueue.async {
                let outcome = Self.runJob(url: url, config: config, ignoreList: ignoreList)
                Task { @MainActor in
                    AppState.shared.record(outcome, source: url, notify: notify)
                }
            }
        }
    }

    /// Läuft auf der Verarbeitungs-Queue: wartet bis die Datei fertig
    /// geschrieben ist und konvertiert sie dann.
    private nonisolated static func runJob(url: URL, config: ProcessingConfig, ignoreList: IgnoreList) -> Result<ProcessingOutcome, Error> {
        guard waitUntilFileIsStable(at: url) else {
            return .success(.skipped("Datei verschwunden oder nie fertig geschrieben"))
        }
        do {
            let outcome = try ImageProcessor.process(fileURL: url, config: config, ignoreList: ignoreList)
            return .success(outcome)
        } catch {
            return .failure(error)
        }
    }

    /// Wartet, bis die Dateigröße über zwei Messungen stabil ist —
    /// Downloads können beim Erscheinen der Datei noch unvollständig sein.
    private nonisolated static func waitUntilFileIsStable(at url: URL, attempts: Int = 30) -> Bool {
        let fileManager = FileManager.default
        var lastSize: Int64 = -1
        for _ in 0..<attempts {
            guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let size = attributes[.size] as? Int64
            else {
                return false
            }
            if size > 0 && size == lastSize {
                return true
            }
            lastSize = size
            Thread.sleep(forTimeInterval: 0.6)
        }
        return false
    }

    private func record(_ outcome: Result<ProcessingOutcome, Error>, source: URL, notify: Bool) {
        switch outcome {
        case .success(.processed(let result)):
            recentResults.insert(result, at: 0)
            if recentResults.count > 20 {
                recentResults.removeLast(recentResults.count - 20)
            }
            totalProcessed += 1
            totalBytesSaved += result.bytesSaved
            lastError = nil
            Self.logger.info("Konvertiert: \(result.sourceName, privacy: .public) → \(result.outputURL.lastPathComponent, privacy: .public) (−\(result.savingsPercent) %)")
            if notify {
                Self.postNotification(for: result)
            }
        case .success(.skipped(let reason)):
            Self.logger.info("Übersprungen: \(source.lastPathComponent, privacy: .public) — \(reason, privacy: .public)")
        case .failure(let error):
            lastError = "\(source.lastPathComponent): \(error.localizedDescription)"
            Self.logger.error("Fehler bei \(source.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    static var runsFromAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    static func requestNotificationPermission() {
        guard runsFromAppBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func postNotification(for result: ProcessingResult) {
        guard runsFromAppBundle else { return }
        let content = UNMutableNotificationContent()
        content.title = "Bild komprimiert"
        let saved = ByteCountFormatter.string(fromByteCount: result.bytesSaved, countStyle: .file)
        content.body = "\(result.sourceName) → \(result.outputURL.lastPathComponent) (−\(result.savingsPercent) %, \(saved) gespart)"
        let request = UNNotificationRequest(identifier: result.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
