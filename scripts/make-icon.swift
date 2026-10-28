// Renders the SafeSweep app icon at every size macOS needs and packs it into AppIcon.icns.
//
//   swift scripts/make-icon.swift
//
// Outputs Resources/AppIcon.icns and docs/icon.png (used by the README).
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

/// Four-pointed sparkle with concave sides.
func sparkle(center c: CGPoint, radius r: CGFloat) -> CGPath {
    let k = r * 0.16
    let path = CGMutablePath()
    path.move(to: CGPoint(x: c.x, y: c.y - r))
    path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
    path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
    path.closeSubpath()
    return path
}

func shieldPath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 512, y: 262))
    path.addCurve(to: CGPoint(x: 718, y: 330), control1: CGPoint(x: 590, y: 318), control2: CGPoint(x: 660, y: 330))
    path.addLine(to: CGPoint(x: 718, y: 520))
    path.addCurve(to: CGPoint(x: 512, y: 786), control1: CGPoint(x: 718, y: 650), control2: CGPoint(x: 628, y: 738))
    path.addCurve(to: CGPoint(x: 306, y: 520), control1: CGPoint(x: 396, y: 738), control2: CGPoint(x: 306, y: 650))
    path.addLine(to: CGPoint(x: 306, y: 330))
    path.addCurve(to: CGPoint(x: 512, y: 262), control1: CGPoint(x: 364, y: 330), control2: CGPoint(x: 434, y: 318))
    path.closeSubpath()
    return path
}

/// Draws the icon in a 1024×1024 top-down coordinate space.
/// Shadow offsets are not affected by the flip, so negative heights point down.
func drawIcon(in ctx: CGContext) {
    // Background squircle, inset per Apple's macOS icon grid (824 pt body on a 1024 canvas).
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.28))
    ctx.addPath(squircle)
    ctx.setFillColor(color(0x2563EB))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(0x3B82F6), color(0x2563EB), color(0x0FB5A3)]),
        start: CGPoint(x: 180, y: 100), end: CGPoint(x: 844, y: 924), options: []
    )
    // Soft highlight across the top for depth.
    ctx.drawRadialGradient(
        gradient([color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)]),
        startCenter: CGPoint(x: 360, y: 180), startRadius: 0,
        endCenter: CGPoint(x: 360, y: 180), endRadius: 620, options: []
    )
    ctx.restoreGState()

    // Shield.
    let shield = shieldPath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: color(0x0B1F4D, 0.35))
    ctx.addPath(shield)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shield)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(0xFFFFFF), color(0xE6EEFF)]),
        start: CGPoint(x: 512, y: 262), end: CGPoint(x: 512, y: 786), options: []
    )
    ctx.restoreGState()

    // Checkmark, filled with the background gradient.
    let check = CGMutablePath()
    check.move(to: CGPoint(x: 400, y: 528))
    check.addLine(to: CGPoint(x: 482, y: 608))
    check.addLine(to: CGPoint(x: 630, y: 440))
    let stroke = check.copy(strokingWithWidth: 62, lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.saveGState()
    ctx.addPath(stroke)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(0x2563EB), color(0x0FB5A3)]),
        start: CGPoint(x: 400, y: 440), end: CGPoint(x: 630, y: 608), options: []
    )
    ctx.restoreGState()

    // Sparkles: "clean".
    ctx.setFillColor(color(0xFFFFFF))
    for (center, radius) in [
        (CGPoint(x: 778, y: 252), CGFloat(78)),
        (CGPoint(x: 846, y: 382), CGFloat(40)),
        (CGPoint(x: 236, y: 770), CGFloat(34)),
    ] {
        ctx.addPath(sparkle(center: center, radius: radius))
        ctx.fillPath()
    }
}

func renderPNG(size: Int, to url: URL) {
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    let scale = CGFloat(size) / canvas
    // Flip to top-down coordinates so the drawing code reads naturally.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)
    drawIcon(in: ctx)

    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    renderPNG(size: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    renderPNG(size: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

for folder in ["Resources", "docs"] {
    try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
}
renderPNG(size: 512, to: root.appendingPathComponent("docs/icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote Resources/AppIcon.icns and docs/icon.png")
