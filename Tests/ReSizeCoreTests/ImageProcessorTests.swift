import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ReSizeCore

final class ImageProcessorTests: XCTestCase {
    private func image(width: Int, height: Int, pixel: (Int, Int) -> [UInt8]) -> CGImage {
        var bytes: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width { bytes += pixel(x, y) }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    private func rgb(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pointer = context.data!.assumingMemoryBound(to: UInt8.self)
        let start = (y * image.width + x) * 4
        return [pointer[start], pointer[start + 1], pointer[start + 2]]
    }

    func testCropOnlyPreservesEverySelectedPixelAndTopLeftCoordinates() throws {
        let source = image(width: 12, height: 10) { x, y in [UInt8(x * 19), UInt8(y * 23), 70, 255] }
        var settings = EditorSettings()
        settings.target = PixelSize(4, 4)
        settings.focus = CGPoint(x: 0.75, y: 0.7)
        let output = try ImageProcessor.verify(ImageProcessor.convertedData(source, settings: settings), settings: settings)
        for y in 0..<4 {
            for x in 0..<4 {
                XCTAssertEqual(rgb(output, x: x, y: y), rgb(source, x: x + 7, y: y + 5))
            }
        }
    }

    func testCropAtAllEdgesStaysInsideSource() {
        for point in [CGPoint(x: -1, y: -1), CGPoint(x: 2, y: 2), CGPoint(x: 0.15, y: 0.75)] {
            var settings = EditorSettings()
            settings.target = PixelSize(2880, 1800)
            settings.focus = point
            let rect = CropGeometry.rect(source: PixelSize(3840, 2160), settings: settings)
            XCTAssertTrue(CGRect(x: 0, y: 0, width: 3840, height: 2160).contains(rect))
            XCTAssertEqual(rect.width, 2880)
            XCTAssertEqual(rect.height, 1800)
            XCTAssertEqual(rect.minX, rect.minX.rounded())
            XCTAssertEqual(rect.minY, rect.minY.rounded())
        }
    }

    func testCropOnlyRejectsInsufficientWidthOrHeight() throws {
        var settings = EditorSettings()
        settings.target = PixelSize(8, 8)
        for size in [PixelSize(7, 20), PixelSize(20, 7)] {
            let source = image(width: size.width, height: size.height) { _, _ in [0, 0, 0, 255] }
            XCTAssertThrowsError(try ImageProcessor.render(source, settings: settings))
        }
    }

    func testFitKeepsWholeImageAndAddsBackground() throws {
        let source = image(width: 8, height: 4) { x, _ in x < 4 ? [255, 0, 0, 255] : [0, 0, 255, 255] }
        var settings = EditorSettings()
        settings.target = PixelSize(8, 8)
        settings.mode = .fit
        let output = try ImageProcessor.render(source, settings: settings)
        XCTAssertEqual(rgb(output, x: 3, y: 0), [255, 255, 255])
        XCTAssertEqual(rgb(output, x: 1, y: 3), [255, 0, 0])
        XCTAssertEqual(rgb(output, x: 6, y: 3), [0, 0, 255])
        XCTAssertEqual(rgb(output, x: 3, y: 7), [255, 255, 255])
    }

    func testCropAndResizeUsesSelectedTopAndBottomAreas() throws {
        let source = image(width: 16, height: 12) { _, y in y < 6 ? [255, 0, 0, 255] : [0, 0, 255, 255] }
        var settings = EditorSettings()
        settings.mode = .cropAndResize
        settings.target = PixelSize(4, 4)
        settings.cropFraction = 0.4
        settings.focus = CGPoint(x: 0.5, y: 0)
        let top = try ImageProcessor.render(source, settings: settings)
        XCTAssertEqual(rgb(top, x: 2, y: 2), [255, 0, 0])
        settings.focus.y = 1
        let bottom = try ImageProcessor.render(source, settings: settings)
        XCTAssertEqual(rgb(bottom, x: 2, y: 2), [0, 0, 255])
    }

    func testCropAndResizeMaintainsAspectBeforeSampling() {
        var settings = EditorSettings()
        settings.mode = .cropAndResize
        settings.target = PixelSize(1440, 900)
        settings.cropFraction = 0.371
        let rect = CropGeometry.rect(source: PixelSize(4031, 2267), settings: settings)
        XCTAssertEqual(rect.width / rect.height, 1.6, accuracy: 0.000001)
        XCTAssertTrue(CGRect(x: 0, y: 0, width: 4031, height: 2267).contains(rect))
    }

    func testTransparencyIsFlattenedAndAlphaChannelRemoved() throws {
        let source = image(width: 4, height: 4) { _, _ in [255, 0, 0, 0] }
        var settings = EditorSettings()
        settings.target = PixelSize(4, 4)
        settings.background = BackgroundColor(red: 0, green: 0, blue: 1)
        let output = try ImageProcessor.verify(ImageProcessor.convertedData(source, settings: settings), settings: settings)
        XCTAssertEqual(rgb(output, x: 1, y: 1), [0, 0, 255])
        XCTAssertTrue([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(output.alphaInfo))
    }

    func testBothFormatsHaveExactDimensionsAndOpaqueRGBOutput() throws {
        let source = image(width: 40, height: 30) { x, y in [UInt8(x * 5), UInt8(y * 7), 100, 255] }
        for format in OutputFormat.allCases {
            var settings = EditorSettings()
            settings.mode = .fit
            settings.target = PixelSize(32, 20)
            settings.format = format
            let output = try ImageProcessor.verify(ImageProcessor.convertedData(source, settings: settings), settings: settings)
            XCTAssertEqual(output.width, 32)
            XCTAssertEqual(output.height, 20)
            XCTAssertEqual(output.colorSpace?.model, .rgb)
            XCTAssertEqual(output.bitsPerComponent, 8)
        }
    }

    func testInvalidOutputSizeDoesNotAllocateABitmap() throws {
        let source = image(width: 2, height: 2) { _, _ in [0, 0, 0, 255] }
        for size in [PixelSize(0, 1), PixelSize(-1, 5), PixelSize(16_385, 1), PixelSize(10_000, 10_000)] {
            var settings = EditorSettings()
            settings.mode = .fit
            settings.target = size
            XCTAssertThrowsError(try ImageProcessor.render(source, settings: settings))
        }
    }

    func testEXIFRotationSwapsDimensionsAndNormalizesPixels() throws {
        let original = image(width: 12, height: 8) { x, _ in x < 6 ? [255, 0, 0, 255] : [0, 0, 255, 255] }
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, original, [kCGImagePropertyOrientation: 6,
                                                         kCGImageDestinationLossyCompressionQuality: 1] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let source = CGImageSourceCreateWithData(data, nil)!
        XCTAssertEqual(try ImageReader.orientedSize(of: source), PixelSize(8, 12))
        let normalized = try ImageReader.image(from: source)
        XCTAssertEqual(normalized.width, 8)
        XCTAssertEqual(normalized.height, 12)
        XCTAssertGreaterThan(rgb(normalized, x: 4, y: 2)[0], 230)
        XCTAssertGreaterThan(rgb(normalized, x: 4, y: 9)[2], 230)
    }

    func testCorruptInputIsRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a picture".utf8).write(to: url)
        XCTAssertThrowsError(try ImageReader.source(at: url))
    }

    func testNamingAvoidsExistingFilesAndNamesReservedByBatch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = directory.appendingPathComponent("image.png")
        try Data([1]).write(to: existing)
        let next = ExportNaming.availableURL(in: directory, name: "image.png")
        let third = ExportNaming.availableURL(in: directory, name: "image.png", reserved: [next])
        XCTAssertNotEqual(next, existing)
        XCTAssertNotEqual(third, next)
        XCTAssertEqual(try Data(contentsOf: existing), Data([1]))
    }

    func testSourceProtectionResolvesSymlinks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("source.png")
        let link = directory.appendingPathComponent("alias.png")
        try Data([1]).write(to: original)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
        XCTAssertTrue(ExportNaming.isSource(link, sources: [original]))
    }

    func testMacPresetsAreExactAndCustomDimensionsAreNotAssumedValid() {
        for size in [PixelSize(1280, 800), PixelSize(1440, 900), PixelSize(2560, 1600), PixelSize(2880, 1800)] {
            XCTAssertTrue(OutputPreset.accepts(size))
        }
        XCTAssertFalse(OutputPreset.accepts(PixelSize(1920, 1200)))
        XCTAssertFalse(OutputPreset.accepts(PixelSize(3840, 2160)))
    }
}
