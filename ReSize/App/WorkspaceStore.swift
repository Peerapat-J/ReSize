import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorItem: Identifiable {
    let asset: ImageAsset
    var settings = EditorSettings()
    var id: UUID { asset.id }
}

struct ExportReport: Identifiable {
    let id = UUID()
    var files: [URL] = []
    var failures: [String] = []
    var cancelled = false
}

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var items: [EditorItem] = []
    @Published var selection: Set<UUID> = []
    @Published private(set) var activeID: UUID?
    @Published private(set) var original: CGImage?
    @Published private(set) var preview: OutputPreview?
    @Published private(set) var isLoading = false
    @Published private(set) var isImporting = false
    @Published private(set) var isRendering = false
    @Published private(set) var isExporting = false
    @Published private(set) var isPresentingPanel = false
    @Published private(set) var exportCompleted = 0
    @Published private(set) var exportTotal = 0
    @Published var showOutput = false
    @Published var zoom: Double = 0
    @Published var errorMessage: String?
    @Published var renderError: String?
    @Published var report: ExportReport?
    @Published var notice: String?

    private let worker = ImageWorker()
    private var loadTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?

    var active: EditorItem? { items.first { $0.id == activeID } }
    var validation: String? {
        guard let active else { return nil }
        return active.settings.validationMessage(source: active.asset.size)
    }
    var canExport: Bool { active != nil && validation == nil && !isExporting && !isLoading && !isPresentingPanel }

    func chooseImages() {
        guard !isPresentingPanel, !isExporting, !isImporting else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose screenshots to prepare. Originals stay unchanged."
        present(panel) { [weak self] response in
            if response == .OK { self?.importURLs(panel.urls) }
        }
    }

    private func present(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        isPresentingPanel = true
        let finished: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            self?.isPresentingPanel = false
            completion(response)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: finished)
        } else {
            panel.begin(completionHandler: finished)
        }
    }

    func importURLs(_ urls: [URL]) {
        guard !isExporting, !isImporting else { return }
        isImporting = true
        notice = nil
        Task {
            var failures: [String] = []
            var firstNewID: UUID?
            for url in urls {
                let resolved = url.resolvingSymlinksInPath().standardizedFileURL
                if items.contains(where: { $0.asset.url.resolvingSymlinksInPath().standardizedFileURL == resolved }) { continue }
                do {
                    let asset = try await worker.importImage(url)
                    items.append(EditorItem(asset: asset))
                    if firstNewID == nil { firstNewID = asset.id }
                } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
            }
            isImporting = false
            if let firstNewID { select([firstNewID]) }
            if !failures.isEmpty { errorMessage = failures.joined(separator: "\n\n") }
        }
    }

    func select(_ ids: Set<UUID>) {
        let newlySelected = ids.subtracting(selection)
        selection = ids
        let next = items.first { newlySelected.contains($0.id) }?.id
            ?? (ids.contains(activeID ?? UUID()) ? activeID : items.first { ids.contains($0.id) }?.id)
        guard next != activeID else { return }
        activeID = next
        zoom = 0
        loadActive()
    }

    private func loadActive() {
        loadTask?.cancel()
        previewTask?.cancel()
        original = nil
        preview = nil
        renderError = nil
        isRendering = false
        guard let item = active else { isLoading = false; return }
        isLoading = true
        loadTask = Task {
            do {
                let image = try await worker.original(item.asset)
                guard !Task.isCancelled, activeID == item.id else { return }
                original = image
                isLoading = false
                schedulePreview()
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                renderError = error.localizedDescription
            }
        }
    }

    func updateSettings(_ change: (inout EditorSettings) -> Void) {
        guard !isExporting, let index = items.firstIndex(where: { $0.id == activeID }) else { return }
        change(&items[index].settings)
        schedulePreview()
    }

    func schedulePreview() {
        previewTask?.cancel()
        preview = nil
        renderError = nil
        guard let item = active, validation == nil, original != nil else {
            isRendering = false
            return
        }
        isRendering = true
        previewTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(180))
                let result = try await worker.preview(item.asset, settings: item.settings)
                guard !Task.isCancelled, activeID == item.id, active?.settings == item.settings else { return }
                preview = result
                isRendering = false
            } catch {
                guard !Task.isCancelled else { return }
                isRendering = false
                renderError = error.localizedDescription
            }
        }
    }

    func removeSelected() {
        guard !isExporting else { return }
        items.removeAll { selection.contains($0.id) }
        select(items.first.map { [$0.id] } ?? [])
    }

    func applySettingsToSelection() {
        guard let settings = active?.settings else { return }
        let ids = selection
        for index in items.indices where ids.contains(items[index].id) && items[index].id != activeID {
            let focus = items[index].settings.focus
            let fraction = items[index].settings.cropFraction
            items[index].settings = settings
            // แต่ละใบจัดภาพไว้คนละมุม คัดลอกแค่ค่าร่วมแล้วเก็บกรอบเดิมของใบนั้นไว้
            items[index].settings.focus = focus
            items[index].settings.cropFraction = fraction
        }
        notice = "Settings applied to \(ids.count) images. Check each crop before exporting."
    }

    func exportCurrent() {
        guard canExport, let item = active else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [item.settings.format == .png ? .png : .jpeg]
        panel.nameFieldStringValue = ExportNaming.suggestedName(source: item.asset.url, settings: item.settings)
        panel.canCreateDirectories = true
        panel.message = "Save a new copy. If the name exists, a numbered copy will be saved."
        present(panel) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let destination = ExportNaming.availableURL(in: url.deletingLastPathComponent(), name: url.lastPathComponent)
            self?.runExport([(item, destination)])
        }
    }

    func exportMany(selectedOnly: Bool = false) {
        guard !isExporting, !isPresentingPanel, !items.isEmpty else { return }
        let pending = selectedOnly ? items.filter { selection.contains($0.id) } : items
        guard !pending.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Save \(pending.count) images. Existing files will get a numbered copy."
        present(panel) { [weak self] response in
            guard response == .OK, let directory = panel.url else { return }
            var reserved: Set<URL> = []
            let jobs = pending.map { item -> (EditorItem, URL) in
                let name = ExportNaming.suggestedName(source: item.asset.url, settings: item.settings)
                let url = ExportNaming.availableURL(in: directory, name: name, reserved: reserved)
                reserved.insert(url.standardizedFileURL)
                return (item, url)
            }
            self?.runExport(jobs)
        }
    }

    private func runExport(_ jobs: [(EditorItem, URL)]) {
        guard !isExporting else { return }
        isExporting = true
        exportCompleted = 0
        exportTotal = jobs.count
        previewTask?.cancel()
        isRendering = false
        let sources = items.map(\.asset.url)
        exportTask = Task {
            var result = ExportReport()
            for (item, url) in jobs {
                if Task.isCancelled { result.cancelled = true; break }
                do {
                    try await worker.export(item.asset, settings: item.settings, to: url, sources: sources)
                    result.files.append(url)
                } catch is CancellationError {
                    result.cancelled = true
                    break
                } catch { result.failures.append("\(item.asset.name): \(error.localizedDescription)") }
                exportCompleted += 1
            }
            isExporting = false
            report = result
            exportTask = nil
            schedulePreview()
        }
    }

    func cancelExport() { exportTask?.cancel() }
}
