import Foundation
import Combine
import UniformTypeIdentifiers

enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case webp
    case heic
    case jpeg
    case png

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        default: return rawValue
        }
    }

    var utType: UTType {
        switch self {
        case .webp: return .webP
        case .heic: return .heic
        case .jpeg: return .jpeg
        case .png: return .png
        }
    }

    var supportsQuality: Bool { self != .png }

    /// Dateiendungen, die bereits diesem Format entsprechen.
    var matchingExtensions: Set<String> {
        switch self {
        case .webp: return ["webp"]
        case .heic: return ["heic", "heif"]
        case .jpeg: return ["jpg", "jpeg"]
        case .png: return ["png"]
        }
    }
}

enum OutputMode: String, CaseIterable, Identifiable, Sendable {
    case sameFolder
    case customFolder

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sameFolder: return "Gleicher Ordner wie Original"
        case .customFolder: return "Eigener Zielordner"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var watcherEnabled: Bool {
        didSet { defaults.set(watcherEnabled, forKey: "watcherEnabled") }
    }

    @Published var watchFolderPath: String {
        didSet { defaults.set(watchFolderPath, forKey: "watchFolderPath") }
    }

    @Published var targetWidth: Int {
        didSet { defaults.set(targetWidth, forKey: "targetWidth") }
    }

    @Published var quality: Double {
        didSet { defaults.set(quality, forKey: "quality") }
    }

    @Published var outputFormat: OutputFormat {
        didSet { defaults.set(outputFormat.rawValue, forKey: "outputFormat") }
    }

    @Published var outputMode: OutputMode {
        didSet { defaults.set(outputMode.rawValue, forKey: "outputMode") }
    }

    @Published var customOutputFolderPath: String {
        didSet { defaults.set(customOutputFolderPath, forKey: "customOutputFolderPath") }
    }

    @Published var deleteOriginal: Bool {
        didSet { defaults.set(deleteOriginal, forKey: "deleteOriginal") }
    }

    @Published var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: "showNotifications") }
    }

    init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? (NSHomeDirectory() + "/Downloads")

        watcherEnabled = defaults.object(forKey: "watcherEnabled") as? Bool ?? true
        watchFolderPath = defaults.string(forKey: "watchFolderPath") ?? downloads
        targetWidth = defaults.object(forKey: "targetWidth") as? Int ?? 1800
        quality = defaults.object(forKey: "quality") as? Double ?? 75
        outputFormat = OutputFormat(rawValue: defaults.string(forKey: "outputFormat") ?? "") ?? .webp
        outputMode = OutputMode(rawValue: defaults.string(forKey: "outputMode") ?? "") ?? .sameFolder
        customOutputFolderPath = defaults.string(forKey: "customOutputFolderPath") ?? ""
        deleteOriginal = defaults.object(forKey: "deleteOriginal") as? Bool ?? false
        showNotifications = defaults.object(forKey: "showNotifications") as? Bool ?? false
    }

    /// Unveränderlicher Schnappschuss der aktuellen Einstellungen für einen Verarbeitungsjob.
    var processingConfig: ProcessingConfig {
        let outputDirectory: URL?
        if outputMode == .customFolder, !customOutputFolderPath.isEmpty {
            outputDirectory = URL(fileURLWithPath: customOutputFolderPath, isDirectory: true)
        } else {
            outputDirectory = nil
        }
        return ProcessingConfig(
            targetWidth: targetWidth,
            quality: quality,
            format: outputFormat,
            outputDirectory: outputDirectory,
            deleteOriginal: deleteOriginal
        )
    }
}
