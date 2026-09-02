import AppKit
import ImageIO
import UniformTypeIdentifiers

let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/private/tmp/resize-fixtures")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func save(name: String, width: Int, height: Int) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    NSGradient(starting: NSColor(red: 0.10, green: 0.19, blue: 0.27, alpha: 1),
               ending: NSColor(red: 0.20, green: 0.43, blue: 0.42, alpha: 1))!.draw(in: bounds, angle: 30)
    func text(_ text: String, x: Double, y: Double, size: Double, color: NSColor = .white) {
        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color
        ])
    }
    text("TOP LEFT", x: 40, y: Double(height) - 80, size: 32)
    text("BOTTOM LEFT", x: 40, y: 35, size: 32)
    text("TOP RIGHT", x: Double(width) - 260, y: Double(height) - 80, size: 32)
    text("BOTTOM RIGHT", x: Double(width) - 320, y: 35, size: 32)
    let panel = bounds.insetBy(dx: Double(width) * 0.16, dy: Double(height) * 0.13)
    NSColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1).setFill()
    NSBezierPath(roundedRect: panel, xRadius: 24, yRadius: 24).fill()
    let sidebar = CGRect(x: panel.minX, y: panel.minY, width: panel.width * 0.24, height: panel.height)
    NSColor(red: 0.90, green: 0.92, blue: 0.91, alpha: 1).setFill()
    sidebar.fill()
    let fontScale = Double(width) / 3840
    for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        color.setFill()
        NSBezierPath(ovalIn: CGRect(x: panel.minX + 30 + Double(index) * 38, y: panel.maxY - 65, width: 24, height: 24)).fill()
    }
    text("Field Notes", x: sidebar.minX + 40, y: sidebar.maxY - 180 * fontScale, size: 46 * fontScale, color: .darkGray)
    for (index, label) in ["All notes", "Ideas", "Projects", "Archive"].enumerated() {
        text(label, x: sidebar.minX + 40, y: sidebar.maxY - (320 + Double(index) * 110) * fontScale,
             size: 36 * fontScale, color: .darkGray)
    }
    let left = sidebar.maxX + 85 * fontScale
    text("A little room to think.", x: left, y: panel.maxY - 220 * fontScale, size: 72 * fontScale, color: .darkGray)
    text("Project notes · September 2026", x: left, y: panel.maxY - 310 * fontScale, size: 30 * fontScale, color: .gray)
    let lines = ["Make the important things easy to see.", "Keep the details that matter.",
                 "Choose a frame. Check the result. Export.", "Small text: ABCDEFG abcdefg 0123456789", "Pixel check: 1 px lines below"]
    for (index, line) in lines.enumerated() {
        text(line, x: left, y: panel.maxY - (480 + Double(index) * 110) * fontScale,
             size: Double(index == 3 ? 18 : 34) * fontScale, color: .darkGray)
    }
    for index in 0..<100 {
        (index.isMultiple(of: 2) ? NSColor.black : NSColor.white).setFill()
        CGRect(x: left + Double(index), y: panel.minY + 120 * fontScale, width: 1, height: 80 * fontScale).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name))
}

try save(name: "sample-4k.png", width: 3840, height: 2160)
try save(name: "sample-small.png", width: 1200, height: 800)
print(destination.path)
