#!/usr/bin/swift
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let bg = NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)
bg.setFill()
NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 226, yRadius: 226).fill()

guard let symbol = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) else {
    fputs("Failed to load SF Symbol\n", stderr)
    exit(1)
}

let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .semibold)
let configured = symbol.withSymbolConfiguration(config) ?? symbol
let symbolSize = NSSize(width: 520, height: 520)
let rect = NSRect(
    x: (size.width - symbolSize.width) / 2,
    y: (size.height - symbolSize.height) / 2,
    width: symbolSize.width,
    height: symbolSize.height
)

NSColor.white.set()
configured.draw(in: rect)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.png"
let url = URL(fileURLWithPath: out)
try png.write(to: url)
print("Wrote \(url.path)")
