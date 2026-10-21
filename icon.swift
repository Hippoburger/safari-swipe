// Draws the app icon (blue squircle with the swipe arrow) and writes AppIcon.icns.
// Usage: swift icon.swift <out-dir>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let set = "\(out)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: 824/1024 body with ~22% corner radius.
    let body = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let squircle = NSBezierPath(roundedRect: body, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(red: 0.20, green: 0.62, blue: 1.00, alpha: 1),
               ending: NSColor(red: 0.05, green: 0.36, blue: 0.86, alpha: 1))!.draw(in: squircle, angle: -90)

    // White circle with the back arrow, like the on-screen overlay.
    let d = s * 0.46
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: (s - d) / 2, y: (s - d) / 2, width: d, height: d)).fill()
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.24, weight: .bold)
        .applying(.init(paletteColors: [NSColor(red: 0.05, green: 0.36, blue: 0.86, alpha: 1)]))
    let arrow = NSImage(systemSymbolName: "arrow.left", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
    arrow.draw(in: NSRect(x: (s - arrow.size.width) / 2, y: (s - arrow.size.height) / 2,
                          width: arrow.size.width, height: arrow.size.height))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for pt in [16, 32, 128, 256, 512] {
    try! draw(pt).write(to: URL(fileURLWithPath: "\(set)/icon_\(pt)x\(pt).png"))
    try! draw(pt * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(pt)x\(pt)@2x.png"))
}
