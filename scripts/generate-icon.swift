// Rebuild with: xcrun swift scripts/generate-icon.swift
// Original vector geometry, rasterized at each macOS icon size using AppKit.
import AppKit
import Foundation

let directory = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func rounded(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func render(_ pixels: Int) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    rounded(NSRect(x: 52, y: 52, width: 920, height: 920), radius: 205,
            color: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.21, alpha: 1))
    let ink = NSColor(srgbRed: 0.92, green: 0.94, blue: 0.97, alpha: 1)
    let outline = NSBezierPath(roundedRect: NSRect(x: 206, y: 322, width: 612, height: 380), xRadius: 52, yRadius: 52)
    ink.setStroke()
    outline.lineWidth = 32
    outline.stroke()
    for y: CGFloat in [580, 486] {
        for column in 0..<6 {
            rounded(NSRect(x: 270 + CGFloat(column) * 84, y: y, width: 52, height: 52), radius: 10, color: ink)
        }
    }
    rounded(NSRect(x: 270, y: 392, width: 52, height: 52), radius: 10, color: ink)
    rounded(NSRect(x: 354, y: 392, width: 304, height: 52), radius: 10, color: ink)
    rounded(NSRect(x: 690, y: 392, width: 52, height: 52), radius: 10, color: ink)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon-\(pixels).png"))
}
for size in [16, 32, 64, 128, 256, 512, 1024] { try render(size) }
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": "icon-\(size * scale).png"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
