#!/bin/bash
# Erzeugt Resources/AppIcon.icns — Farbverlauf-Kachel mit Foto-Symbol.
# Muss nur nach Design-Änderungen erneut ausgeführt werden; das Ergebnis
# ist im Repository eingecheckt.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET" Resources

swift - "$ICONSET" <<'EOF'
import AppKit

let iconsetPath = CommandLine.arguments[1]

func renderIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(pixels)
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    // macOS-Icons haben einen Rand von ca. 10 % um die Kachel.
    let tile = canvas.insetBy(dx: size * 0.09, dy: size * 0.09)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: size * 0.185, yRadius: size * 0.185)

    NSGradient(colors: [
        NSColor(calibratedRed: 0.25, green: 0.42, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.55, green: 0.22, blue: 0.87, alpha: 1),
    ])!.draw(in: tilePath, angle: -60)

    // Foto-Symbol: weiße abgerundete Rahmenkarte mit Sonne und Bergen.
    let card = tile.insetBy(dx: tile.width * 0.20, dy: tile.height * 0.26)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: size * 0.045, yRadius: size * 0.045)
    cardPath.lineWidth = max(1, size * 0.038)
    NSColor.white.setStroke()
    cardPath.stroke()

    NSColor.white.setFill()
    let sunDiameter = card.width * 0.17
    let sun = NSRect(
        x: card.minX + card.width * 0.16,
        y: card.maxY - card.height * 0.24 - sunDiameter,
        width: sunDiameter, height: sunDiameter
    )
    NSBezierPath(ovalIn: sun).fill()

    let mountains = NSBezierPath()
    let inset = cardPath.lineWidth
    let base = card.minY + inset / 2
    mountains.move(to: NSPoint(x: card.minX + inset / 2, y: base))
    mountains.line(to: NSPoint(x: card.minX + inset / 2, y: base + card.height * 0.18))
    mountains.line(to: NSPoint(x: card.minX + card.width * 0.34, y: base + card.height * 0.52))
    mountains.line(to: NSPoint(x: card.minX + card.width * 0.52, y: base + card.height * 0.28))
    mountains.line(to: NSPoint(x: card.minX + card.width * 0.66, y: base + card.height * 0.42))
    mountains.line(to: NSPoint(x: card.maxX - inset / 2, y: base + card.height * 0.08))
    mountains.line(to: NSPoint(x: card.maxX - inset / 2, y: base))
    mountains.close()

    NSGraphicsContext.current?.cgContext.saveGState()
    cardPath.addClip()
    mountains.fill()
    NSGraphicsContext.current?.cgContext.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in variants {
    let url = URL(fileURLWithPath: iconsetPath).appendingPathComponent("\(name).png")
    try! renderIcon(pixels: pixels).write(to: url)
}
print("Iconset geschrieben: \(iconsetPath)")
EOF

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Fertig: Resources/AppIcon.icns"
