import Foundation

/// Überwacht einen Ordner auf neu erscheinende Dateien über eine
/// DispatchSource auf dem Verzeichnis-Dateideskriptor.
/// Nur Dateien, die NACH dem Start hinzukommen, werden gemeldet.
final class FolderWatcher: @unchecked Sendable {
    enum WatcherError: LocalizedError {
        case cannotOpenDirectory(String)

        var errorDescription: String? {
            switch self {
            case .cannotOpenDirectory(let path):
                return "Ordner kann nicht geöffnet werden: \(path)"
            }
        }
    }

    private let directoryURL: URL
    private let queue = DispatchQueue(label: "com.picpress.app.watcher", qos: .utility)
    private let onNewFiles: ([URL]) -> Void

    private var source: DispatchSourceFileSystemObject?
    private var knownFiles = Set<String>()
    private var pendingScan: DispatchWorkItem?

    /// `onNewFiles` wird auf einer Hintergrund-Queue aufgerufen.
    init(directoryURL: URL, onNewFiles: @escaping ([URL]) -> Void) {
        self.directoryURL = directoryURL
        self.onNewFiles = onNewFiles
    }

    deinit {
        stop()
    }

    func start() throws {
        stop()

        let fd = open(directoryURL.path, O_EVTONLY)
        guard fd >= 0 else {
            throw WatcherError.cannotOpenDirectory(directoryURL.path)
        }

        knownFiles = Self.listing(of: directoryURL)

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename],
            queue: queue
        )
        newSource.setEventHandler { [weak self] in
            self?.scheduleScan()
        }
        newSource.setCancelHandler {
            close(fd)
        }
        newSource.resume()
        source = newSource
    }

    func stop() {
        source?.cancel()
        source = nil
        pendingScan?.cancel()
        pendingScan = nil
    }

    /// Ereignisse kurz entprellen — beim Download entstehen viele Events in Folge.
    private func scheduleScan() {
        pendingScan?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.scan()
        }
        pendingScan = workItem
        queue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func scan() {
        let current = Self.listing(of: directoryURL)
        let newFiles = current.subtracting(knownFiles)
        knownFiles = current
        guard !newFiles.isEmpty else { return }
        onNewFiles(newFiles.sorted().map { directoryURL.appendingPathComponent($0) })
    }

    private static func listing(of directory: URL) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(names.filter { !$0.hasPrefix(".") })
    }
}
