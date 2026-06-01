import AppKit

let outputDirectory = CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset"
try FileManager.default.createDirectory(
    atPath: outputDirectory,
    withIntermediateDirectories: true
)

let iconSizes: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for iconSize in iconSizes {
    let image = drawIcon(size: iconSize.pixels)
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "PathsIcon", code: 1)
    }

    let outputURL = URL(fileURLWithPath: outputDirectory).appendingPathComponent(iconSize.name)
    try pngData.write(to: outputURL)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    NSColor(red: 0.08, green: 0.38, blue: 0.56, alpha: 1).setFill()
    NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

    let folderRect = NSRect(
        x: size * 0.17,
        y: size * 0.28,
        width: size * 0.66,
        height: size * 0.42
    )
    let tabRect = NSRect(
        x: folderRect.minX + size * 0.04,
        y: folderRect.maxY - size * 0.08,
        width: size * 0.24,
        height: size * 0.12
    )

    let folderPath = NSBezierPath()
    folderPath.move(to: NSPoint(x: folderRect.minX, y: folderRect.minY))
    folderPath.line(to: NSPoint(x: folderRect.minX, y: folderRect.maxY - size * 0.11))
    folderPath.curve(
        to: NSPoint(x: tabRect.minX + size * 0.03, y: tabRect.maxY),
        controlPoint1: NSPoint(x: folderRect.minX, y: folderRect.maxY - size * 0.05),
        controlPoint2: NSPoint(x: tabRect.minX, y: tabRect.maxY)
    )
    folderPath.line(to: NSPoint(x: tabRect.maxX, y: tabRect.maxY))
    folderPath.line(to: NSPoint(x: tabRect.maxX + size * 0.06, y: folderRect.maxY))
    folderPath.line(to: NSPoint(x: folderRect.maxX, y: folderRect.maxY))
    folderPath.curve(
        to: NSPoint(x: folderRect.maxX, y: folderRect.minY),
        controlPoint1: NSPoint(x: folderRect.maxX + size * 0.03, y: folderRect.maxY - size * 0.12),
        controlPoint2: NSPoint(x: folderRect.maxX + size * 0.03, y: folderRect.minY + size * 0.08)
    )
    folderPath.close()
    NSColor(white: 0.97, alpha: 1).setFill()
    folderPath.fill()

    let pathStroke = NSBezierPath()
    pathStroke.lineWidth = max(2, size * 0.065)
    pathStroke.lineCapStyle = .round
    pathStroke.move(to: NSPoint(x: size * 0.43, y: size * 0.35))
    pathStroke.line(to: NSPoint(x: size * 0.57, y: size * 0.59))
    NSColor(red: 0.08, green: 0.38, blue: 0.56, alpha: 1).setStroke()
    pathStroke.stroke()

    image.unlockFocus()
    return image
}
