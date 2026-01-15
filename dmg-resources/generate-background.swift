#!/usr/bin/env swift
import Cocoa

// DMG window dimensions
let width = 660
let height = 400

// Colors
let bgTop = NSColor(red: 45/255, green: 52/255, blue: 64/255, alpha: 1.0)
let bgBottom = NSColor(red: 28/255, green: 32/255, blue: 40/255, alpha: 1.0)
let arrowColor = NSColor(white: 1.0, alpha: 0.7)
let textColor = NSColor(red: 180/255, green: 185/255, blue: 195/255, alpha: 1.0)

func createDMGBackground(scale: CGFloat) -> NSImage {
    let scaledWidth = CGFloat(width) * scale
    let scaledHeight = CGFloat(height) * scale

    let image = NSImage(size: NSSize(width: scaledWidth, height: scaledHeight))

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Draw gradient background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [bgTop.cgColor, bgBottom.cgColor] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: scaledHeight),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }

    // Icon positions (match AppleScript positioning)
    let appIconCenterX: CGFloat = 140 * scale
    let appsIconCenterX: CGFloat = 520 * scale
    let iconY: CGFloat = (CGFloat(height) - 180) * scale  // Flip Y for Core Graphics

    // Draw dashed arrow
    let arrowY = iconY - 5 * scale
    let arrowStartX = appIconCenterX + 60 * scale
    let arrowEndX = appsIconCenterX - 60 * scale

    context.setStrokeColor(arrowColor.cgColor)
    context.setLineWidth(3 * scale)
    context.setLineDash(phase: 0, lengths: [12 * scale, 8 * scale])

    context.move(to: CGPoint(x: arrowStartX, y: arrowY))
    context.addLine(to: CGPoint(x: arrowEndX - 20 * scale, y: arrowY))
    context.strokePath()

    // Draw arrowhead (solid)
    context.setLineDash(phase: 0, lengths: [])
    context.setFillColor(arrowColor.cgColor)

    let arrowSize: CGFloat = 16 * scale
    let arrowTipX = arrowEndX - 10 * scale

    context.move(to: CGPoint(x: arrowTipX, y: arrowY))
    context.addLine(to: CGPoint(x: arrowTipX - arrowSize, y: arrowY + arrowSize * 0.6))
    context.addLine(to: CGPoint(x: arrowTipX - arrowSize, y: arrowY - arrowSize * 0.6))
    context.closePath()
    context.fillPath()

    // Draw title text
    let titleFont = NSFont.systemFont(ofSize: 20 * scale, weight: .medium)
    let title = "Luzia Universal Typo Correcter"
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor(white: 1.0, alpha: 0.9)
    ]
    let titleSize = title.size(withAttributes: titleAttributes)
    let titleX = (scaledWidth - titleSize.width) / 2
    let titleY = scaledHeight - 55 * scale

    title.draw(at: NSPoint(x: titleX, y: titleY), withAttributes: titleAttributes)

    // Draw instruction text
    let instructionFont = NSFont.systemFont(ofSize: 14 * scale, weight: .regular)
    let instruction = "Drag to Applications folder to install"
    let instructionAttributes: [NSAttributedString.Key: Any] = [
        .font: instructionFont,
        .foregroundColor: textColor
    ]
    let instructionSize = instruction.size(withAttributes: instructionAttributes)
    let instructionX = (scaledWidth - instructionSize.width) / 2
    let instructionY: CGFloat = 30 * scale

    instruction.draw(at: NSPoint(x: instructionX, y: instructionY), withAttributes: instructionAttributes)

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Error: Could not create PNG data")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path)")
    } catch {
        print("Error writing file: \(error)")
    }
}

// Generate 1x and 2x versions
let scriptPath = CommandLine.arguments[0]
let scriptDir = (scriptPath as NSString).deletingLastPathComponent
let outputDir = scriptDir.isEmpty ? "." : scriptDir

let image1x = createDMGBackground(scale: 1.0)
let image2x = createDMGBackground(scale: 2.0)

savePNG(image1x, to: "\(outputDir)/dmg-background.png")
savePNG(image2x, to: "\(outputDir)/dmg-background@2x.png")

print("Background dimensions: \(width)x\(height)")
