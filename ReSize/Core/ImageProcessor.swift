import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ImageProcessor {
    public static func render(_ image: CGImage, settings: EditorSettings) throws -> CGImage {
        let source = PixelSize(image.width, image.height)
        if let message = settings.validationMessage(source: source) {
            throw ConverterError.message(message)
        }
        let target = settings.target
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: target.width, height: target.height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw ConverterError.message("There isn't enough memory to prepare this image.")
        }
        context.setFillColor(settings.background.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: target.width, height: target.height))
        context.interpolationQuality = .high

        switch settings.mode {
        case .cropOnly:
            let rect = CropGeometry.rect(source: source, settings: settings)
            guard let cropped = image.cropping(to: rect) else {
                throw ConverterError.message("The crop falls outside the image.")
            }
            context.interpolationQuality = .none
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: target.width, height: target.height))
        case .cropAndResize:
            let crop = CropGeometry.rect(source: source, settings: settings)
            let scale = Double(target.width) / crop.width
            // กรอบใน UI นับจากมุมซ้ายบน แต่ CGContext นับจากด้านล่าง
            let bottom = Double(source.height) - crop.maxY
            context.draw(image, in: CGRect(x: -crop.minX * scale, y: -bottom * scale,
                                           width: Double(source.width) * scale,
                                           height: Double(source.height) * scale))
        case .fit:
            let scale = settings.scale(source: source)
            let width = Double(source.width) * scale
            let height = Double(source.height) * scale
            context.draw(image, in: CGRect(x: (Double(target.width) - width) / 2,
                                           y: (Double(target.height) - height) / 2,
                                           width: width, height: height))
        }
        guard let output = context.makeImage() else {
            throw ConverterError.message("Couldn't create the output image.")
        }
        return output
    }

    public static func encode(_ image: CGImage, settings: EditorSettings) throws -> Data {
        let data = NSMutableData()
        let type = settings.format == .png ? UTType.png.identifier : UTType.jpeg.identifier
        guard let destination = CGImageDestinationCreateWithData(data, type as CFString, 1, nil) else {
            throw ConverterError.message("Couldn't prepare the output file.")
        }
        var properties: [CFString: Any] = [kCGImagePropertyOrientation: 1]
        if settings.format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = min(1, max(0.1, settings.jpegQuality))
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConverterError.message("Couldn't finish encoding the image.")
        }
        return data as Data
    }

    public static func verify(_ data: Data, settings: EditorSettings) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let type = CGImageSourceGetType(source) as String? else {
            throw ConverterError.message("The exported file couldn't be opened for verification.")
        }
        let expected = settings.format == .png ? UTType.png.identifier : UTType.jpeg.identifier
        let alpha = image.alphaInfo
        let opaque = alpha == .none || alpha == .noneSkipFirst || alpha == .noneSkipLast
        guard image.width == settings.target.width, image.height == settings.target.height,
              type == expected, opaque else {
            throw ConverterError.message("The exported file doesn't match the chosen size or format.")
        }
        return image
    }

    public static func convertedData(_ image: CGImage, settings: EditorSettings) throws -> Data {
        try encode(render(image, settings: settings), settings: settings)
    }
}
