import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ImageReader {
    public static func source(at url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) as String?,
              type == UTType.png.identifier || type == UTType.jpeg.identifier else {
            throw ConverterError.message("Choose a PNG or JPEG image.")
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              PixelSize(width, height).isSupported else {
            throw ConverterError.message("This image is unreadable or larger than 60 megapixels (16,384 px per side).")
        }
        return source
    }

    public static func image(from source: CGImageSource, maximumSize: Int? = nil) throws -> CGImage {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = properties?[kCGImagePropertyOrientation] as? Int ?? 1
        if maximumSize == nil && orientation == 1,
           let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) {
            return image
        }
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumSize ?? max(width, height),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ConverterError.message("Couldn't decode this image. The file may be damaged.")
        }
        return image
    }

    public static func orientedSize(of source: CGImageSource) throws -> PixelSize {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ConverterError.message("Couldn't read the image dimensions.")
        }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return (5...8).contains(orientation) ? PixelSize(height, width) : PixelSize(width, height)
    }
}
