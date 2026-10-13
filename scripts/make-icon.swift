// Draws the NoMess app icon and builds Resources/AppIcon.icns.
//   swift scripts/make-icon.swift
// Clean paragraph lines with a sparkle: copied text, already tidied.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
let output = root.appendingPathComponent("Resources/AppIcon.icns")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Four-pointed star centred at `c`.
func sparkle(at c: CGPoint, radius r: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let waist = r * 0.28
    path.move(to: CGPoint(x: c.x, y: c.y + r))
    path.curve(to: CGPoint(x: c.x + r, y: c.y), controlPoint1: CGPoint(x: c.x + waist * 0.4, y: c.y + waist), controlPoint2: CGPoint(x: c.x + waist, y: c.y + waist * 0.4))
    path.curve(to: CGPoint(x: c.x, y: c.y - r), controlPoint1: CGPoint(x: c.x + waist, y: c.y - waist * 0.4), controlPoint2: CGPoint(x: c.x + waist * 0.4, y: c.y - waist))
    path.curve(to: CGPoint(x: c.x - r, y: c.y), controlPoint1: CGPoint(x: c.x - waist * 0.4, y: c.y - waist), controlPoint2: CGPoint(x: c.x - waist, y: c.y - waist * 0.4))
    path.curve(to: CGPoint(x: c.x, y: c.y + r), controlPoint1: CGPoint(x: c.x - waist, y: c.y + waist * 0.4), controlPoint2: CGPoint(x: c.x - waist * 0.4, y: c.y + waist))
    path.close()
    return path
}

/// Draws on a 1024-point canvas, following the macOS icon grid: an 824-point
/// rounded square centred, with room for the drop shadow.
func drawIcon(in ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 28
    shadow.set()
    color(0x4338CA).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [color(0x6D5BF6), color(0x4338CA), color(0x2E1F8F)])!
        .draw(in: body, angle: -60)
    // Soft highlight across the top.
    NSGradient(colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)])!
        .draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Three tidy lines of text, the last one shorter.
    let left: CGFloat = 250
    let barHeight: CGFloat = 78
    let bars: [(y: CGFloat, width: CGFloat)] = [(560, 524), (420, 524), (280, 330)]
    for bar in bars {
        let rect = CGRect(x: left, y: bar.y, width: bar.width, height: barHeight)
        NSGraphicsContext.saveGraphicsState()
        let barShadow = NSShadow()
        barShadow.shadowColor = color(0x1E1065, 0.35)
        barShadow.shadowOffset = NSSize(width: 0, height: -6)
        barShadow.shadowBlurRadius = 10
        barShadow.set()
        color(0xFFFFFF).setFill()
        NSBezierPath(roundedRect: rect, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    // Sparkle: it's been cleaned.
    color(0xFFD166).setFill()
    sparkle(at: CGPoint(x: 690, y: 330), radius: 110).fill()
    color(0xFFE29A).setFill()
    sparkle(at: CGPoint(x: 800, y: 760), radius: 52).fill()
}

func png(size pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let ctx = context.cgContext
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try png(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try png(size: 1024).write(to: root.appendingPathComponent("build/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
print("Wrote \(output.path)")
