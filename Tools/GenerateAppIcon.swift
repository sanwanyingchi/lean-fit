import AppKit
import CoreGraphics

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift GenerateAppIcon.swift <output.png>")
}

let pixelSize = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let cgContext = CGContext(
    data: nil,
    width: pixelSize,
    height: pixelSize,
    bitsPerComponent: 8,
    bytesPerRow: pixelSize * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Unable to create app icon bitmap")
}

let context = NSGraphicsContext(cgContext: cgContext, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

let bounds = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
let brandCoral = NSColor(red: 1, green: 75.0 / 255.0, blue: 43.0 / 255.0, alpha: 1)
let progressPlum = NSColor(red: 110.0 / 255.0, green: 64.0 / 255.0, blue: 91.0 / 255.0, alpha: 1)

brandCoral.setFill()
bounds.fill()

let logoPath = NSBezierPath()
logoPath.move(to: NSPoint(x: 304, y: 738))
logoPath.line(to: NSPoint(x: 304, y: 320))
logoPath.line(to: NSPoint(x: 452, y: 320))
logoPath.line(to: NSPoint(x: 570, y: 438))
logoPath.line(to: NSPoint(x: 570, y: 738))
logoPath.line(to: NSPoint(x: 748, y: 738))
logoPath.move(to: NSPoint(x: 570, y: 554))
logoPath.line(to: NSPoint(x: 696, y: 554))
logoPath.lineWidth = 88
logoPath.lineCapStyle = .round
logoPath.lineJoinStyle = .round
NSColor.white.setStroke()
logoPath.stroke()

progressPlum.setFill()
NSBezierPath(ovalIn: NSRect(x: 722, y: 712, width: 52, height: 52)).fill()

NSGraphicsContext.restoreGraphicsState()

guard let cgImage = cgContext.makeImage() else {
    fatalError("Unable to finalize app icon image")
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
bitmap.size = NSSize(width: pixelSize, height: pixelSize)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render app icon")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
