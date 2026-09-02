import Foundation
import CoreGraphics

public struct PixelSize: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
    }

    public var aspect: Double { Double(width) / Double(max(1, height)) }
    public var label: String { "\(width) × \(height)" }
    public var isSupported: Bool {
        width > 0 && height > 0 && width <= 16_384 && height <= 16_384
            && Int64(width) * Int64(height) <= 60_000_000
    }
}

public enum ResizeMode: String, CaseIterable, Sendable {
    case cropOnly = "Crop Only"
    case cropAndResize = "Crop & Resize"
    case fit = "Fit"

    public var explanation: String {
        switch self {
        case .cropOnly: "Move a fixed-size frame. Keep the original pixel detail."
        case .cropAndResize: "Choose an area, then resize it to your output size."
        case .fit: "Keep the whole image and fill the remaining space."
        }
    }
}

public enum OutputFormat: String, CaseIterable, Sendable {
    case png = "PNG"
    case jpeg = "JPEG"
    public var fileExtension: String { self == .png ? "png" : "jpg" }
}

public enum OutputPreset: String, CaseIterable, Sendable {
    case mac2880 = "Mac · 2880 × 1800"
    case mac2560 = "Mac · 2560 × 1600"
    case mac1440 = "Mac · 1440 × 900"
    case mac1280 = "Mac · 1280 × 800"
    case custom = "Custom"

    public var size: PixelSize? {
        switch self {
        case .mac2880: PixelSize(2880, 1800)
        case .mac2560: PixelSize(2560, 1600)
        case .mac1440: PixelSize(1440, 900)
        case .mac1280: PixelSize(1280, 800)
        case .custom: nil
        }
    }

    public static func accepts(_ size: PixelSize) -> Bool {
        allCases.contains { $0.size == size }
    }
}

public struct BackgroundColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = Self(red: 1, green: 1, blue: 1)
    public var cgColor: CGColor {
        CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                components: [red, green, blue, 1])!
    }
}

public struct EditorSettings: Equatable, Sendable {
    public var mode: ResizeMode = .cropOnly
    public var preset: OutputPreset = .mac2880
    public var target = PixelSize(2880, 1800)
    public var format: OutputFormat = .png
    public var jpegQuality: Double = 0.95
    public var background: BackgroundColor = .white
    public var focus = CGPoint(x: 0.5, y: 0.5)
    public var cropFraction: Double = 1

    public init() {}

    public mutating func selectPreset(_ preset: OutputPreset) {
        self.preset = preset
        if let size = preset.size { target = size }
    }

    public mutating func resetFraming() {
        focus = CGPoint(x: 0.5, y: 0.5)
        cropFraction = 1
    }

    public func validationMessage(source: PixelSize) -> String? {
        guard target.isSupported else {
            return "Choose a size from 1–16,384 px per side, up to 60 megapixels."
        }
        if mode == .cropOnly && (target.width > source.width || target.height > source.height) {
            return "This image is too small for a \(target.label) crop. Choose a smaller size or another mode."
        }
        return nil
    }

    public func scale(source: PixelSize) -> Double {
        switch mode {
        case .cropOnly: 1
        case .cropAndResize: Double(target.width) / CropGeometry.rect(source: source, settings: self).width
        case .fit: min(Double(target.width) / Double(source.width), Double(target.height) / Double(source.height))
        }
    }
}

public enum ConverterError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}
