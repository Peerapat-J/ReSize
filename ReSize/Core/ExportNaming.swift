import Foundation

public enum ExportNaming {
    public static func suggestedName(source: URL, settings: EditorSettings) -> String {
        "\(source.deletingPathExtension().lastPathComponent)-\(settings.target.width)x\(settings.target.height).\(settings.format.fileExtension)"
    }

    public static func availableURL(in directory: URL, name: String, reserved: Set<URL> = []) -> URL {
        let original = directory.appendingPathComponent(name)
        var candidate = original
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) || reserved.contains(candidate.standardizedFileURL) {
            candidate = original.deletingPathExtension()
                .appendingPathExtension("\(index).\(original.pathExtension)")
            index += 1
        }
        return candidate
    }

    public static func isSource(_ destination: URL, sources: [URL]) -> Bool {
        let resolved = destination.resolvingSymlinksInPath().standardizedFileURL
        return sources.contains {
            $0.resolvingSymlinksInPath().standardizedFileURL == resolved
        }
    }
}
