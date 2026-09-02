import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                emptyState
            } else {
                HSplitView {
                    sidebar.frame(minWidth: 190, idealWidth: 210, maxWidth: 240)
                    editor.frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
                    InspectorView(store: store)
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 1060, minHeight: 660)
        .background(.background)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 3).padding(8)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: acceptDrop)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: store.chooseImages) { Label("Open Images…", systemImage: "plus") }
                    .disabled(store.isExporting || store.isImporting)
                    .help("Open PNG or JPEG images (⌘O)")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if store.items.count > 1 {
                    Menu {
                        Button("Export All \(store.items.count) Images…") { store.exportMany() }
                        if store.selection.count > 1 {
                            Button("Export \(store.selection.count) Selected Images…") { store.exportMany(selectedOnly: true) }
                        }
                    } label: { Label("Export All", systemImage: "square.stack") }
                    .disabled(store.isExporting || store.isImporting)
                }
                Button(action: store.exportCurrent) { Label("Export…", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canExport)
            }
        }
        .alert("Couldn't complete that", isPresented: Binding(get: { store.errorMessage != nil }, set: {
            if !$0 { store.errorMessage = nil }
        })) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .sheet(item: $store.report) { report in
            ExportReportView(report: report)
        }
        .onOpenURL { store.importURLs([$0]) }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "crop")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 100, height: 100)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 25))
            Text("A better fit for the App Store.").font(.system(size: 27, weight: .semibold))
            Text("Drop your screenshots here. Choose a frame, check the result, and export.")
                .font(.body).foregroundStyle(.secondary)
            Button("Open Images…", action: store.chooseImages)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(store.isImporting)
            Text("PNG or JPEG · Everything stays on your Mac")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 30) {
                Label("Crop Only", systemImage: "crop")
                Label("Crop & Resize", systemImage: "arrow.up.left.and.arrow.down.right")
                Label("Fit", systemImage: "rectangle.inset.filled")
            }.font(.callout).foregroundStyle(.secondary).padding(.bottom, 35)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("IMAGES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(store.items.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }.padding(.horizontal, 15).padding(.vertical, 14)
            List(selection: Binding(get: { store.selection }, set: { store.select($0) })) {
                ForEach(store.items) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        Image(decorative: item.asset.thumbnail, scale: 1)
                            .resizable().scaledToFit()
                            .frame(maxWidth: .infinity).frame(height: 82)
                            .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                        Text(item.asset.name).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                        HStack {
                            Text(item.asset.size.label).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Spacer()
                            if item.settings.validationMessage(source: item.asset.size) != nil {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                                    .help("This image needs a different crop size or mode.")
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .tag(item.id)
                    .accessibilityElement(children: .combine)
                }
            }.listStyle(.sidebar)
                .disabled(store.isExporting)
            Divider()
            HStack {
                Button(action: store.removeSelected) { Image(systemName: "minus") }
                    .buttonStyle(.borderless).help("Remove selected images from this session")
                    .accessibilityLabel("Remove selected images")
                    .disabled(store.selection.isEmpty || store.isExporting)
                Spacer()
                Text("⌘ click to select more").font(.caption2).foregroundStyle(.secondary)
            }.padding(12)
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.active?.asset.name ?? "Choose an image")
                        .font(.headline).lineLimit(1).truncationMode(.middle)
                    Text(store.showOutput ? "Encoded export preview" :
                        (store.active?.settings.mode == .fit ? "The whole image stays in your output" : "Drag the frame to choose what stays"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)
                Picker("Preview", selection: $store.showOutput) {
                    Text("Source").tag(false)
                    Text("Output").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 148)
            }.padding(16)
            Divider()
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                if let item = store.active {
                    if let image = store.showOutput ? store.preview?.image : store.original {
                        CropCanvas(image: image, sourceSize: item.asset.size, settings: item.settings,
                                   showsOutput: store.showOutput, zoom: store.zoom, isEditable: !store.isExporting) { focus, fraction in
                            store.updateSettings { $0.focus = focus; $0.cropFraction = fraction }
                        }
                    } else if store.isLoading || store.isRendering {
                        ProgressView(store.isLoading ? "Opening image…" : "Preparing preview…")
                    } else {
                        ContentUnavailableView("No preview", systemImage: "photo",
                                               description: Text(store.validation ?? store.renderError ?? "Select an image to begin."))
                    }
                }
            }
            if let message = store.validation ?? store.renderError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.padding(12).background(.orange.opacity(0.08))
            }
            Divider()
            HStack {
                Picker("View zoom", selection: $store.zoom) {
                    Text("Fit to Window").tag(0.0)
                    Text("50%").tag(0.5)
                    Text("100%").tag(1.0)
                    Text("200%").tag(2.0)
                }.frame(width: 155).labelsHidden()
                    .help("100% shows one image pixel per display pixel. Zoom never changes the export.")
                Spacer()
                if let item = store.active, item.settings.mode != .fit, !store.showOutput, store.validation == nil {
                    let rect = CropGeometry.rect(source: item.asset.size, settings: item.settings)
                    Text("x \(Int(rect.minX))  y \(Int(rect.minY)) · \(Int(rect.width)) × \(Int(rect.height)) px")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 14).padding(.vertical, 10)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if store.isExporting {
                ProgressView(value: Double(store.exportCompleted), total: Double(max(1, store.exportTotal)))
                    .frame(width: 140)
                Text("Exporting \(store.exportCompleted) of \(store.exportTotal)…").font(.callout)
                Button("Cancel", action: store.cancelExport).controlSize(.small)
            } else if store.isImporting {
                ProgressView().controlSize(.small)
                Text("Opening images…").font(.callout)
            } else if let item = store.active {
                Image(systemName: item.settings.mode == .cropOnly ? "crop" : "arrow.up.left.and.arrow.down.right")
                    .foregroundStyle(Color.accentColor)
                Text(operationDescription(item)).font(.callout)
                Spacer()
                if store.isRendering {
                    ProgressView().controlSize(.small)
                    Text("Updating preview…").font(.caption).foregroundStyle(.secondary)
                } else if let preview = store.preview {
                    Text("\(item.settings.format.rawValue) · \(ByteCountFormatter.string(fromByteCount: Int64(preview.byteCount), countStyle: .file))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "lock").foregroundStyle(.secondary)
                Text("Local processing. Exported copies keep your originals safe.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if store.active == nil || store.isExporting || store.isImporting { Spacer() }
        }.padding(.horizontal, 18).frame(height: 43)
    }

    private func operationDescription(_ item: EditorItem) -> String {
        if store.validation != nil { return "Check the output size" }
        let scale = item.settings.scale(source: item.asset.size)
        switch item.settings.mode {
        case .cropOnly: return "Crop only · no resizing"
        case .cropAndResize: return "\(scale > 1 ? "Upscaling" : "Resize") to \(Int((scale * 100).rounded()))% · \(item.settings.target.label) px"
        case .fit: return "Fit · \(scale > 1 ? "upscaling to" : "scale") \(Int((scale * 100).rounded()))% · background added if needed"
        }
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !store.isExporting, !store.isImporting else { return false }
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                let url: URL? = await withCheckedContinuation { continuation in
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        continuation.resume(returning: data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) })
                    }
                }
                if let url { urls.append(url) }
            }
            store.importURLs(urls)
        }
        return true
    }
}

struct ExportReportView: View {
    let report: ExportReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(report.cancelled ? "Export stopped" : "Export finished",
                  systemImage: report.failures.isEmpty && !report.cancelled ? "checkmark.circle.fill" : "info.circle")
                .font(.title2.weight(.semibold)).foregroundStyle(Color.accentColor)
            Text("\(report.files.count) saved · \(report.failures.count) failed")
            if report.cancelled {
                Text("Completed files are saved. Remaining images were skipped.").foregroundStyle(.secondary)
            }
            if !report.failures.isEmpty {
                ScrollView {
                    Text(report.failures.joined(separator: "\n\n"))
                        .font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 200)
            }
            if !report.files.isEmpty {
                Text(report.files.count == 1 ? report.files[0].lastPathComponent : "Your exported images are ready.")
                    .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            HStack {
                if !report.files.isEmpty {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(report.files) }
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(28).frame(width: 460)
    }
}
