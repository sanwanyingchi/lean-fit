#!/usr/bin/env swift

import AppKit
import AVFoundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: ExtractVideoFrames.swift <video> <output-directory>")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let asset = AVURLAsset(url: inputURL)
let duration = CMTimeGetSeconds(asset.duration)
guard duration.isFinite, duration > 0 else { fatalError("Video duration is unavailable") }

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

for index in 0..<8 {
    let seconds = duration * Double(index + 1) / 9
    let image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode frame \(index)")
    }
    try data.write(to: outputURL.appendingPathComponent(String(format: "frame-%02d.png", index + 1)))
}
