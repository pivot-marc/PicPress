import Foundation
import CoreGraphics
import libwebp

/// WebP-Encoding über libwebp (statisch einkompiliert) —
/// macOS ImageIO kann WebP nur lesen, nicht schreiben.
enum WebPEncoder {
    enum EncoderError: LocalizedError {
        case bitmapContextFailed
        case encodeFailed

        var errorDescription: String? {
            switch self {
            case .bitmapContextFailed: return "Bitmap-Kontext konnte nicht erstellt werden."
            case .encodeFailed: return "libwebp-Encoder meldete einen Fehler."
            }
        }
    }

    /// Encodiert ein CGImage als verlustbehaftetes WebP und schreibt es an `url`.
    /// `quality` in Prozent (1…100).
    static func encode(_ image: CGImage, to url: URL, quality: Double) throws {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ),
              let buffer = { () -> UnsafeMutablePointer<UInt8>? in
                  context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                  return context.data?.assumingMemoryBound(to: UInt8.self)
              }()
        else {
            throw EncoderError.bitmapContextFailed
        }

        // CGContext liefert premultipliziertes Alpha, libwebp erwartet straight
        // Alpha — für teiltransparente Pixel zurückrechnen.
        let hasAlpha = image.alphaInfo != .none && image.alphaInfo != .noneSkipLast && image.alphaInfo != .noneSkipFirst
        if hasAlpha {
            for pixelIndex in 0..<(width * height) {
                let offset = pixelIndex * 4
                let alpha = buffer[offset + 3]
                if alpha != 0 && alpha != 255 {
                    let a = UInt32(alpha)
                    buffer[offset] = UInt8(min(255, UInt32(buffer[offset]) * 255 / a))
                    buffer[offset + 1] = UInt8(min(255, UInt32(buffer[offset + 1]) * 255 / a))
                    buffer[offset + 2] = UInt8(min(255, UInt32(buffer[offset + 2]) * 255 / a))
                }
            }
        }

        var output: UnsafeMutablePointer<UInt8>?
        let clampedQuality = Float(min(max(quality, 1), 100))
        let outputSize = WebPEncodeRGBA(buffer, Int32(width), Int32(height), Int32(bytesPerRow), clampedQuality, &output)

        guard outputSize > 0, let output else {
            throw EncoderError.encodeFailed
        }
        defer { WebPFree(output) }

        let data = Data(bytes: output, count: outputSize)
        try data.write(to: url, options: .atomic)
    }
}
