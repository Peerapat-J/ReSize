import Foundation
import CoreGraphics

struct FileStamp: Equatable, Sendable {
    let size: Int?
    let modified: Date?

    init(url: URL) throws {
        // URL จำ metadata เก่าไว้ได้ อ่านจากดิสก์ใหม่ตรงนี้เพื่อจับไฟล์ที่ถูกแก้ข้างนอก
        let values = try FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path)
        size = (values[.size] as? NSNumber)?.intValue
        modified = values[.modificationDate] as? Date
    }
}

struct ImageAsset: Identifiable, @unchecked Sendable {
    let id: UUID
    let url: URL
    let size: PixelSize
    let thumbnail: CGImage
    let stamp: FileStamp
    var name: String { url.lastPathComponent }
}

struct OutputPreview: @unchecked Sendable {
    let image: CGImage
    let byteCount: Int
}

actor ImageWorker {
    private var cachedID: UUID?
    private var cachedImage: CGImage?

    func importImage(_ url: URL) throws -> ImageAsset {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        try Task.checkCancellation()
        let source = try ImageReader.source(at: url)
        return try ImageAsset(id: UUID(), url: url, size: ImageReader.orientedSize(of: source),
                              thumbnail: ImageReader.image(from: source, maximumSize: 420),
                              stamp: FileStamp(url: url))
    }

    func original(_ asset: ImageAsset) throws -> CGImage {
        let access = asset.url.startAccessingSecurityScopedResource()
        defer { if access { asset.url.stopAccessingSecurityScopedResource() } }
        try Task.checkCancellation()
        guard try FileStamp(url: asset.url) == asset.stamp else {
            throw ConverterError.message("\(asset.name) changed on disk. Remove it and open it again before exporting.")
        }
        if cachedID == asset.id, let cachedImage { return cachedImage }
        let image = try ImageReader.image(from: ImageReader.source(at: asset.url))
        // เก็บภาพเต็มแค่ใบล่าสุด รายการด้านซ้ายใช้รูปย่อ จะได้ไม่กินแรมตามจำนวนไฟล์
        cachedImage = image
        cachedID = asset.id
        return image
    }

    func preview(_ asset: ImageAsset, settings: EditorSettings) throws -> OutputPreview {
        let image = try original(asset)
        let data = try ImageProcessor.convertedData(image, settings: settings)
        try Task.checkCancellation()
        return try OutputPreview(image: ImageProcessor.verify(data, settings: settings), byteCount: data.count)
    }

    func export(_ asset: ImageAsset, settings: EditorSettings, to url: URL, sources: [URL]) throws {
        let access = url.deletingLastPathComponent().startAccessingSecurityScopedResource()
        defer { if access { url.deletingLastPathComponent().stopAccessingSecurityScopedResource() } }
        guard !ExportNaming.isSource(url, sources: sources) else {
            throw ConverterError.message("Choose a different filename so the original stays safe.")
        }
        let data = try ImageProcessor.convertedData(original(asset), settings: settings)
        _ = try ImageProcessor.verify(data, settings: settings)
        try Task.checkCancellation()
        // ตรวจไฟล์ชั่วคราวก่อน แล้วค่อยย้ายไปชื่อจริง ไฟล์ปลายทางจะไม่เหลือครึ่ง ๆ กลาง ๆ
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".resize-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary, options: .withoutOverwriting)
        _ = try ImageProcessor.verify(Data(contentsOf: temporary), settings: settings)
        try Task.checkCancellation()
        // ไม่เขียนทับไฟล์ที่มีอยู่ แม้จะมีไฟล์ใหม่โผล่มาระหว่างรอ Export
        try FileManager.default.moveItem(at: temporary, to: url)
    }
}
