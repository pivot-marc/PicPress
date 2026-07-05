import Foundation

/// Headless-Modus zum Testen und für Scripting:
///   PicPress --process <datei> [--width 1800] [--quality 75] [--format webp] [--out <ordner>] [--delete-original]
enum CommandLineRunner {
    static func run() {
        var arguments = Array(CommandLine.arguments.dropFirst())

        func value(for flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            let result = arguments[index + 1]
            arguments.removeSubrange(index...(index + 1))
            return result
        }

        guard let filePath = value(for: "--process") else {
            FileHandle.standardError.write(Data("Verwendung: PicPress --process <datei> [--width n] [--quality n] [--format webp|heic|jpeg|png] [--out <ordner>] [--delete-original]\n".utf8))
            exit(64)
        }

        let width = value(for: "--width").flatMap(Int.init) ?? 1800
        let quality = value(for: "--quality").flatMap(Double.init) ?? 75
        let format = value(for: "--format").flatMap(OutputFormat.init(rawValue:)) ?? .webp
        let outputDirectory = value(for: "--out").map { URL(fileURLWithPath: $0, isDirectory: true) }
        let deleteOriginal = arguments.contains("--delete-original")

        let config = ProcessingConfig(
            targetWidth: width,
            quality: quality,
            format: format,
            outputDirectory: outputDirectory,
            deleteOriginal: deleteOriginal
        )

        let fileURL = URL(fileURLWithPath: filePath)
        do {
            let outcome = try ImageProcessor.process(fileURL: fileURL, config: config, ignoreList: IgnoreList())
            switch outcome {
            case .processed(let result):
                let before = ByteCountFormatter.string(fromByteCount: result.sourceBytes, countStyle: .file)
                let after = ByteCountFormatter.string(fromByteCount: result.outputBytes, countStyle: .file)
                print("OK: \(result.outputURL.path)")
                print("\(before) → \(after) (−\(result.savingsPercent) %)\(result.wasResized ? ", verkleinert auf max. \(width) px Breite" : "")")
            case .skipped(let reason):
                print("Übersprungen: \(reason)")
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("Fehler: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
