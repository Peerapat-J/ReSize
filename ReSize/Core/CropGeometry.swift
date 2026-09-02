import Foundation
import CoreGraphics

public enum CropGeometry {
    public static func maximumCrop(source: PixelSize, target: PixelSize) -> CGSize {
        guard source.isSupported, target.isSupported else { return .zero }
        let width = min(Double(source.width), Double(source.height) * target.aspect)
        return CGSize(width: width, height: width / target.aspect)
    }

    public static func rect(source: PixelSize, settings: EditorSettings) -> CGRect {
        guard source.isSupported, settings.target.isSupported else { return .zero }
        let size: CGSize
        if settings.mode == .cropOnly {
            size = CGSize(width: settings.target.width, height: settings.target.height)
        } else {
            let maximum = maximumCrop(source: source, target: settings.target)
            let fraction = min(1, max(0.01, settings.cropFraction))
            size = CGSize(width: maximum.width * fraction, height: maximum.height * fraction)
        }
        var x = min(max(0, settings.focus.x * Double(source.width) - size.width / 2),
                    max(0, Double(source.width) - size.width))
        var y = min(max(0, settings.focus.y * Double(source.height) - size.height / 2),
                    max(0, Double(source.height) - size.height))
        // กรอบ Crop Only ต้องลงพิกเซลพอดี ไม่งั้นตอนตัดขอบจะคลาดไปนิดหนึ่ง
        if settings.mode == .cropOnly {
            x = x.rounded()
            y = y.rounded()
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    public static func moving(_ rect: CGRect, by delta: CGSize, source: PixelSize) -> CGPoint {
        let x = min(max(0, rect.minX + delta.width), max(0, Double(source.width) - rect.width))
        let y = min(max(0, rect.minY + delta.height), max(0, Double(source.height) - rect.height))
        return CGPoint(x: (x + rect.width / 2) / Double(source.width),
                       y: (y + rect.height / 2) / Double(source.height))
    }
}
