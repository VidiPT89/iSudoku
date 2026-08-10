#!/usr/bin/swift
import AppKit
import CoreGraphics

// Amber 3x3 Sudoku grid glyph on the dark ividi.dev-matched background, matching the motif
// used for DroidSudoku's adaptive launcher icon: rounded outer frame, two evenly-spaced
// internal dividers each way (nine cells), one filled "given digit" dot in the center cell.

let S: CGFloat = 1024
let outDir = (NSString(string:
    "~/Desktop/PROGRAMMING/Programas feitos por mim/Sudoku/iSudoku/iSudoku/Assets.xcassets/AppIcon.appiconset")
    as NSString).expandingTildeInPath as String

let bg = CGColor(red: 0x0a / 255.0, green: 0x0a / 255.0, blue: 0x0f / 255.0, alpha: 1)
let amber = CGColor(red: 0xf5 / 255.0, green: 0x9e / 255.0, blue: 0x0b / 255.0, alpha: 1)
let amberDim = CGColor(red: 0xf5 / 255.0, green: 0x9e / 255.0, blue: 0x0b / 255.0, alpha: 0.10)

func renderIcon(size: Int) -> CGImage {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                         space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: s); ctx.scaleBy(x: 1, y: -1)

    // Background — square; Xcode/AppKit apply the platform mask (rounded corners on iOS/mac).
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // Faint ambient glow behind the grid, matching the app's radial-gradient background style.
    let glow = CGGradient(colorsSpace: cs,
        colors: [CGColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 0.22),
                 CGColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 0)] as CFArray,
        locations: [0, 1])!
    ctx.drawRadialGradient(glow,
        startCenter: CGPoint(x: s * 0.5, y: s * 0.42), startRadius: 0,
        endCenter: CGPoint(x: s * 0.5, y: s * 0.42), endRadius: s * 0.62,
        options: [])

    // Outer rounded frame (the grid boundary).
    let m = s * 0.20
    let frame = CGRect(x: m, y: m, width: s - 2 * m, height: s - 2 * m)
    let framePath = CGMutablePath()
    framePath.addRoundedRect(in: frame, cornerWidth: s * 0.037, cornerHeight: s * 0.037)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.05, color: CGColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 0.55))
    ctx.setFillColor(amber)
    ctx.addPath(framePath)
    ctx.fillPath()
    ctx.restoreGState()

    // Cut nine cells out of the frame by drawing background-colored dividers on top,
    // inset slightly so the amber grid lines remain visible (matches DroidSudoku's glyph).
    let inset = s * 0.035
    let inner = frame.insetBy(dx: inset, dy: inset)
    let third = inner.width / 3
    let lineW = s * 0.0075

    ctx.setFillColor(bg)
    // Horizontal dividers
    for i in 1...2 {
        let y = inner.minY + third * CGFloat(i)
        ctx.fill(CGRect(x: inner.minX, y: y - lineW / 2, width: inner.width, height: lineW))
    }
    // Vertical dividers
    for i in 1...2 {
        let x = inner.minX + third * CGFloat(i)
        ctx.fill(CGRect(x: x - lineW / 2, y: inner.minY, width: lineW, height: inner.height))
    }

    // Center "given digit" dot.
    let dotR = s * 0.028
    let cx = inner.minX + inner.width / 2
    let cy = inner.minY + inner.height / 2
    ctx.setFillColor(bg)
    ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))

    return ctx.makeImage()!
}

func write(_ image: CGImage, to filename: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    let path = outDir + "/" + filename
    try! data.write(to: URL(fileURLWithPath: path))
    print("✓ \(filename)")
}

let sizes: [(Int, String)] = [
    (16, "icon-16.png"), (20, "icon-20.png"), (29, "icon-29.png"), (32, "icon-32.png"),
    (40, "icon-40.png"), (58, "icon-58.png"), (60, "icon-60.png"), (64, "icon-64.png"),
    (76, "icon-76.png"), (80, "icon-80.png"), (87, "icon-87.png"), (120, "icon-120.png"),
    (128, "icon-128.png"), (152, "icon-152.png"), (167, "icon-167.png"), (180, "icon-180.png"),
    (256, "icon-256.png"), (512, "icon-512.png"), (1024, "icon-1024.png")
]

for (size, filename) in sizes {
    write(renderIcon(size: size), to: filename)
}
print("Done — \(sizes.count) icon sizes generated.")
