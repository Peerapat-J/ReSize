import AppKit
import SwiftUI

struct CropCanvas: NSViewRepresentable {
    let image: CGImage
    let sourceSize: PixelSize
    let settings: EditorSettings
    let showsOutput: Bool
    let zoom: Double
    let isEditable: Bool
    let onChange: (CGPoint, Double) -> Void

    func makeNSView(context: Context) -> CanvasScrollView {
        let scroll = CanvasScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.contentView.postsBoundsChangedNotifications = true
        scroll.documentView = scroll.canvas
        return scroll
    }

    func updateNSView(_ scroll: CanvasScrollView, context: Context) {
        let canvas = scroll.canvas
        canvas.image = image
        canvas.sourceSize = sourceSize
        canvas.settings = settings
        canvas.showsOutput = showsOutput
        canvas.zoom = zoom
        canvas.isEditable = isEditable
        canvas.onChange = onChange
        scroll.needsLayout = true
        canvas.needsDisplay = true
        canvas.setAccessibilityElement(true)
        canvas.setAccessibilityRole(.image)
        let hasCrop = !showsOutput && settings.mode != .fit
        canvas.setAccessibilityLabel(showsOutput ? "Export preview" : (hasCrop ? "Source image and crop frame" : "Source image"))
        canvas.setAccessibilityHelp(hasCrop ? "Use arrow keys to move the crop one pixel. Hold Shift for ten pixels." :
            "Use the zoom menu to inspect image detail. Zoom does not change the output.")
        let crop = CropGeometry.rect(source: sourceSize, settings: settings)
        canvas.setAccessibilityValue(hasCrop ?
            "Crop at x \(Int(crop.minX)), y \(Int(crop.minY)); \(Int(crop.width)) by \(Int(crop.height)) pixels" :
            (showsOutput ? settings.target : sourceSize).label + " pixels")
    }
}

final class CanvasScrollView: NSScrollView {
    let canvas = CropCanvasView()
    override func layout() {
        super.layout()
        canvas.updateLayout(viewport: contentSize)
    }
}

final class CropCanvasView: NSView {
    var image: CGImage?
    var sourceSize = PixelSize(1, 1)
    var settings = EditorSettings()
    var showsOutput = false
    var zoom: Double = 0
    var isEditable = true
    var onChange: ((CGPoint, Double) -> Void)?
    private var imageRect = CGRect.zero
    private var displayScale: Double = 1
    private var startPoint = CGPoint.zero
    private var startCrop = CGRect.zero
    private var corner: Int?
    private var dragging = false

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { isEditable && !showsOutput }

    func updateLayout(viewport: CGSize) {
        guard let image, viewport.width > 0, viewport.height > 0 else { return }
        let fit = min(max(1, viewport.width - 64) / Double(image.width),
                      max(1, viewport.height - 64) / Double(image.height))
        // 100% คือ 1 พิกเซลภาพต่อ 1 พิกเซลจอ ไม่ใช่ 1 point ของ macOS
        displayScale = zoom == 0 ? fit : zoom / (window?.backingScaleFactor ?? 2)
        let imageSize = CGSize(width: Double(image.width) * displayScale,
                               height: Double(image.height) * displayScale)
        let documentSize = CGSize(width: max(viewport.width, imageSize.width + 64),
                                  height: max(viewport.height, imageSize.height + 64))
        setFrameSize(documentSize)
        imageRect = CGRect(x: (documentSize.width - imageSize.width) / 2,
                           y: (documentSize.height - imageSize.height) / 2,
                           width: imageSize.width, height: imageSize.height)
        needsDisplay = true
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        enclosingScrollView?.needsLayout = true
    }

    private func viewRect(_ rect: CGRect) -> CGRect {
        CGRect(x: imageRect.minX + rect.minX * displayScale,
               y: imageRect.minY + rect.minY * displayScale,
               width: rect.width * displayScale, height: rect.height * displayScale)
    }

    private func corners(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        guard let image else { return }
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(0.15)
        shadow.shadowBlurRadius = 18
        shadow.shadowOffset = CGSize(width: 0, height: -2)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor.white.setFill()
        imageRect.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
            .draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1,
                  respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])

        guard !showsOutput, settings.mode != .fit, settings.target.isSupported else { return }
        let crop = CropGeometry.rect(source: sourceSize, settings: settings)
        let frame = viewRect(crop).intersection(imageRect)
        let shade = NSBezierPath(rect: imageRect)
        shade.appendRect(frame)
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.55).setFill()
        shade.fill()

        let valid = settings.validationMessage(source: sourceSize) == nil
        (valid ? NSColor.white : NSColor.systemOrange).setStroke()
        let border = NSBezierPath(rect: frame.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1.5
        border.stroke()
        if dragging {
            NSColor.white.withAlphaComponent(0.35).setStroke()
            let grid = NSBezierPath()
            for part in 1...2 {
                let x = frame.minX + frame.width * Double(part) / 3
                let y = frame.minY + frame.height * Double(part) / 3
                grid.move(to: CGPoint(x: x, y: frame.minY))
                grid.line(to: CGPoint(x: x, y: frame.maxY))
                grid.move(to: CGPoint(x: frame.minX, y: y))
                grid.line(to: CGPoint(x: frame.maxX, y: y))
            }
            grid.lineWidth = 0.5
            grid.stroke()
        }
        if settings.mode == .cropAndResize && valid {
            for point in corners(frame) {
                let handle = NSBezierPath(roundedRect: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8),
                                          xRadius: 2, yRadius: 2)
                NSColor.white.setFill()
                handle.fill()
                NSColor.black.withAlphaComponent(0.4).setStroke()
                handle.stroke()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEditable, !showsOutput, settings.mode != .fit,
              settings.validationMessage(source: sourceSize) == nil else { return }
        window?.makeFirstResponder(self)
        startPoint = convert(event.locationInWindow, from: nil)
        startCrop = CropGeometry.rect(source: sourceSize, settings: settings)
        let frame = viewRect(startCrop)
        corner = settings.mode == .cropAndResize ? corners(frame).firstIndex {
            hypot($0.x - startPoint.x, $0.y - startPoint.y) <= 12
        } : nil
        dragging = frame.insetBy(dx: -10, dy: -10).contains(startPoint)
        if dragging { NSCursor.closedHand.push() }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        let delta = CGSize(width: (point.x - startPoint.x) / displayScale,
                           height: (point.y - startPoint.y) / displayScale)
        if let corner {
            resize(from: corner, delta: delta)
        } else {
            onChange?(CropGeometry.moving(startCrop, by: delta, source: sourceSize), settings.cropFraction)
        }
    }

    private func resize(from corner: Int, delta: CGSize) {
        let left = corner == 0 || corner == 2
        let top = corner == 0 || corner == 1
        let anchor = CGPoint(x: left ? startCrop.maxX : startCrop.minX,
                             y: top ? startCrop.maxY : startCrop.minY)
        let aspect = settings.target.aspect
        let widthChange = abs(delta.width) >= abs(delta.height * aspect)
            ? (left ? -delta.width : delta.width) : (top ? -delta.height : delta.height) * aspect
        let availableWidth = left ? anchor.x : Double(sourceSize.width) - anchor.x
        let availableHeight = top ? anchor.y : Double(sourceSize.height) - anchor.y
        let limit = min(availableWidth, availableHeight * aspect)
        let maximum = CropGeometry.maximumCrop(source: sourceSize, target: settings.target)
        let minimum = min(limit, max(maximum.width * 0.01, 8))
        let width = min(limit, max(minimum, startCrop.width + widthChange))
        let height = width / aspect
        let x = left ? anchor.x - width : anchor.x
        let y = top ? anchor.y - height : anchor.y
        onChange?(CGPoint(x: (x + width / 2) / Double(sourceSize.width),
                          y: (y + height / 2) / Double(sourceSize.height)), width / maximum.width)
    }

    override func mouseUp(with event: NSEvent) {
        if dragging { NSCursor.pop() }
        dragging = false
        corner = nil
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isEditable, !showsOutput, settings.mode != .fit,
              settings.validationMessage(source: sourceSize) == nil else { super.keyDown(with: event); return }
        let step = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        let delta: CGSize
        switch event.keyCode {
        case 123: delta = CGSize(width: -step, height: 0)
        case 124: delta = CGSize(width: step, height: 0)
        case 125: delta = CGSize(width: 0, height: step)
        case 126: delta = CGSize(width: 0, height: -step)
        default: super.keyDown(with: event); return
        }
        onChange?(CropGeometry.moving(CropGeometry.rect(source: sourceSize, settings: settings),
                                     by: delta, source: sourceSize), settings.cropFraction)
    }
}
