import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: Double(pixels) / 1024, y: Double(pixels) / 1024)
        let tile = NSBezierPath(roundedRect: CGRect(x: 70, y: 70, width: 884, height: 884), xRadius: 195, yRadius: 195)
        // ใช้เส้น crop เดิม เปลี่ยนแค่โทนให้เข้ากับไอคอนขาวเทาของ QRSpell
        NSGradient(starting: NSColor(white: 0.80, alpha: 1),
                   ending: NSColor(white: 0.95, alpha: 1))!.draw(in: tile, angle: 90)
        NSColor.white.withAlphaComponent(0.65).setStroke()
        tile.lineWidth = 6
        tile.stroke()
        NSColor.black.withAlphaComponent(0.045).setFill()
        NSBezierPath(roundedRect: CGRect(x: 285, y: 275, width: 480, height: 440), xRadius: 42, yRadius: 42).fill()
        NSColor(white: 0.12, alpha: 1).setStroke()
        let crop = NSBezierPath()
        crop.lineWidth = 58
        crop.lineCapStyle = .round
        crop.lineJoinStyle = .round
        crop.move(to: CGPoint(x: 230, y: 710))
        crop.line(to: CGPoint(x: 705, y: 710))
        crop.line(to: CGPoint(x: 705, y: 220))
        crop.move(to: CGPoint(x: 320, y: 804))
        crop.line(to: CGPoint(x: 320, y: 315))
        crop.line(to: CGPoint(x: 802, y: 315))
        crop.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon-\(size)@\(scale)x.png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: directory.appendingPathComponent("Contents.json"))
