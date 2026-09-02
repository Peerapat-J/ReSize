import XCTest
import CoreGraphics
@testable import ReSizeCore

@MainActor
final class ExportWorkflowTests: XCTestCase {
    private func fixture(in directory: URL) throws -> URL {
        let context = CGContext(data: nil, width: 20, height: 12, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 12))
        let url = directory.appendingPathComponent("source.png")
        var settings = EditorSettings()
        settings.target = PixelSize(20, 12)
        try ImageProcessor.encode(context.makeImage()!, settings: settings).write(to: url)
        return url
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("resize-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testExportWritesVerifiedFileAndLeavesOriginalUnchanged() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try fixture(in: directory)
        let original = try Data(contentsOf: source)
        let worker = ImageWorker()
        let asset = try await worker.importImage(source)
        var settings = EditorSettings()
        settings.target = PixelSize(8, 6)
        let target = directory.appendingPathComponent("export.png")
        try await worker.export(asset, settings: settings, to: target, sources: [source])
        _ = try ImageProcessor.verify(Data(contentsOf: target), settings: settings)
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2)
    }

    func testExportDoesNotReplaceFileCreatedAfterChoosingDestination() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try fixture(in: directory)
        let worker = ImageWorker()
        let asset = try await worker.importImage(source)
        var settings = EditorSettings()
        settings.target = PixelSize(8, 6)
        let target = directory.appendingPathComponent("export.png")
        let sentinel = Data("already here".utf8)
        try sentinel.write(to: target)
        do {
            try await worker.export(asset, settings: settings, to: target, sources: [source])
            XCTFail("Should refuse to overwrite an existing file")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: target), sentinel)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2)
    }

    func testExportRejectsSourceChangedSinceImport() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try fixture(in: directory)
        let worker = ImageWorker()
        let asset = try await worker.importImage(source)
        var changed = try Data(contentsOf: source)
        changed.append(0)
        try changed.write(to: source)
        do {
            _ = try await worker.original(asset)
            XCTFail("Should ask to reopen a changed source")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("changed on disk"))
        }
    }

    func testCancelledExportDoesNotLeavePartialFiles() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try fixture(in: directory)
        let worker = ImageWorker()
        let asset = try await worker.importImage(source)
        var settings = EditorSettings()
        settings.target = PixelSize(8, 6)
        let target = directory.appendingPathComponent("export.png")
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await worker.export(asset, settings: settings, to: target, sources: [source])
        }
        do {
            try await task.value
            XCTFail("Should cancel before writing")
        } catch is CancellationError {} catch { XCTFail(error.localizedDescription) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)
    }

    func testPreviewAndExportContainTheSameDecodedJPEG() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try fixture(in: directory)
        let worker = ImageWorker()
        let asset = try await worker.importImage(source)
        var settings = EditorSettings()
        settings.target = PixelSize(8, 6)
        settings.format = .jpeg
        settings.jpegQuality = 0.6
        let preview = try await worker.preview(asset, settings: settings)
        let target = directory.appendingPathComponent("export.jpg")
        try await worker.export(asset, settings: settings, to: target, sources: [source])
        let data = try Data(contentsOf: target)
        let decoded = try ImageProcessor.verify(data, settings: settings)
        XCTAssertEqual(preview.byteCount, data.count)
        XCTAssertEqual(preview.image.dataProvider?.data as Data?, decoded.dataProvider?.data as Data?)
    }
}
