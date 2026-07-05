import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct ProcessingConfig: Sendable {
    var targetWidth: Int
    var quality: Double // 1...100
    var format: OutputFormat
    var outputDirectory: URL? // nil = gleicher Ordner wie das Original
    var deleteOriginal: Bool
}

struct ProcessingResult: Identifiable, Sendable {
    let id = UUID()
    let sourceName: String
    let outputURL: URL
    let sourceBytes: Int64
    let outputBytes: Int64
    let wasResized: Bool
    let date: Date

    var bytesSaved: Int64 { max(0, sourceBytes - outputBytes) }

    var savingsPercent: Int {
        guard sourceBytes > 0 else { return 0 }
        return Int((Double(sourceBytes - outputBytes) / Double(sourceBytes) * 100).rounded())
    }
}

enum ProcessingOutcome: Sendable {
    case processed(ProcessingResult)
    case skipped(String)
}

enum ProcessingError: LocalizedError {
    case notAnImage
    case decodeFailed
    case encodeFailed(String)
    case outputDirectoryUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .notAnImage:
            return "Datei ist kein lesbares Bild."
        case .decodeFailed:
            return "Bild konnte nicht dekodiert werden."
        case .encodeFailed(let detail):
            return "Bild konnte nicht gespeichert werden: \(detail)"
        case .outputDirectoryUnavailable(let path):
            return "Zielordner nicht verfügbar: \(path)"
        }
    }
}

/// Verlustfreie Menge von Pfaden, die von der App selbst erzeugt wurden und
/// vom Watcher ignoriert werden müssen (verhindert Endlosschleifen).
final class IgnoreList: @unchecked Sendable {
    private var paths = Set<String>()
    private let lock = NSLock()

    func add(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        paths.insert(path)
    }

    func contains(_ path: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return paths.contains(path)
    }
}

enum ImageProcessor {
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "tif", "tiff", "bmp", "heic", "heif", "webp",
    ]

    /// Dateiendungen unfertiger Downloads, die niemals angefasst werden.
    static let partialDownloadExtensions: Set<String> = [
        "crdownload", "download", "part", "partial", "tmp", "aria2",
    ]

    static func isSupportedImage(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Verarbeitet ein einzelnes Bild gemäß Konfiguration.
    /// Vor dem Schreiben wird der Zielpfad in `ignoreList` eingetragen,
    /// damit der Ordner-Watcher die eigene Ausgabe nicht erneut verarbeitet.
    static func process(fileURL: URL, config: ProcessingConfig, ignoreList: IgnoreList) throws -> ProcessingOutcome {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let rawWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let rawHeight = properties[kCGImagePropertyPixelHeight] as? Int,
              rawWidth > 0, rawHeight > 0
        else {
            throw ProcessingError.notAnImage
        }

        // EXIF-Orientierung 5–8 vertauscht Breite und Höhe in der Darstellung.
        let orientation = (properties[kCGImagePropertyOrientation] as? UInt32).map(Int.init) ?? 1
        let dimensionsSwapped = (5...8).contains(orientation)
        let displayWidth = dimensionsSwapped ? rawHeight : rawWidth

        let needsResize = config.targetWidth > 0 && displayWidth > config.targetWidth
        let sourceExtension = fileURL.pathExtension.lowercased()

        // Gleiche Format-Familie und keine Verkleinerung nötig → nichts zu tun.
        if !needsResize && config.format.matchingExtensions.contains(sourceExtension) {
            return .skipped("Bereits im Zielformat und nicht breiter als \(config.targetWidth) px")
        }

        let maxPixelSize: Int
        if needsResize {
            let scale = Double(config.targetWidth) / Double(displayWidth)
            maxPixelSize = max(1, Int((Double(max(rawWidth, rawHeight)) * scale).rounded()))
        } else {
            maxPixelSize = max(rawWidth, rawHeight)
        }

        // Thumbnail-Pfad auch ohne Resize verwenden, damit die EXIF-Orientierung
        // in die Pixel eingerechnet wird (Transform).
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw ProcessingError.decodeFailed
        }

        let outputDirectory = config.outputDirectory ?? fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            throw ProcessingError.outputDirectoryUnavailable(outputDirectory.path)
        }

        let destinationURL = availableDestination(
            for: fileURL.deletingPathExtension().lastPathComponent,
            fileExtension: config.format.fileExtension,
            in: outputDirectory,
            avoiding: fileURL
        )

        ignoreList.add(destinationURL.path)

        do {
            try encode(image, format: config.format, quality: config.quality, to: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }

        let sourceBytes = fileSize(at: fileURL)
        let outputBytes = fileSize(at: destinationURL)

        if config.deleteOriginal && destinationURL.path != fileURL.path {
            try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
        }

        return .processed(ProcessingResult(
            sourceName: fileURL.lastPathComponent,
            outputURL: destinationURL,
            sourceBytes: sourceBytes,
            outputBytes: outputBytes,
            wasResized: needsResize,
            date: Date()
        ))
    }

    /// WebP läuft über den einkompilierten libwebp-Encoder,
    /// alle übrigen Formate über ImageIO.
    private static func encode(_ image: CGImage, format: OutputFormat, quality: Double, to url: URL) throws {
        if format == .webp {
            try WebPEncoder.encode(image, to: url, quality: quality)
            return
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ProcessingError.encodeFailed("Format \(format.displayName) wird von diesem System nicht unterstützt")
        }

        var destinationProperties: [CFString: Any] = [:]
        if format.supportsQuality {
            let clamped = min(max(quality, 1), 100)
            destinationProperties[kCGImageDestinationLossyCompressionQuality] = clamped / 100.0
        }
        CGImageDestinationAddImage(destination, image, destinationProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ProcessingError.encodeFailed("Encoder meldete einen Fehler")
        }
    }

    /// Findet einen freien Zieldateinamen (`name.webp`, `name-2.webp`, …) und
    /// stellt sicher, dass niemals die Quelldatei überschrieben wird.
    private static func availableDestination(
        for baseName: String,
        fileExtension: String,
        in directory: URL,
        avoiding sourceURL: URL
    ) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) || candidate.path == sourceURL.path {
            candidate = directory
                .appendingPathComponent("\(baseName)-\(counter)")
                .appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }

    private static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? Int64) ?? 0
    }
}
