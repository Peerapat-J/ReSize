import SwiftUI
import AppKit

struct InspectorView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var lockAspect = false
    @State private var lockedRatio = 1.6

    private var settings: EditorSettings { store.active?.settings ?? EditorSettings() }

    private func binding<Value>(_ keyPath: WritableKeyPath<EditorSettings, Value>) -> Binding<Value> {
        Binding(get: { settings[keyPath: keyPath] }, set: { value in
            store.updateSettings { $0[keyPath: keyPath] = value }
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prepare your image").font(.headline)
                    Text("Choose what stays in the frame.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                outputSize
                Divider()
                framing
                Divider()
                fileOptions
                Divider()
                if let item = store.active {
                    Label(OutputPreset.accepts(settings.target) ? "Mac screenshot size" : "Custom output size",
                          systemImage: OutputPreset.accepts(settings.target) ? "checkmark.seal" : "ruler")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("\(item.asset.size.label) → \(settings.target.label) px")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                if store.selection.count > 1 {
                    Button("Apply Settings to \(store.selection.count) Selected") {
                        store.applySettingsToSelection()
                    }
                    .help("Copy size, mode, format and background. Keep each image's own crop position.")
                    Text("Crop positions stay individual.").font(.caption).foregroundStyle(.secondary)
                }
                if let notice = store.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .frame(width: 284)
        .background(.background)
        .disabled(store.active == nil || store.isExporting)
        .onChange(of: store.activeID) { _, _ in lockAspect = false }
    }

    private var outputSize: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OUTPUT SIZE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Picker("Preset", selection: Binding(get: { settings.preset }, set: { preset in
                store.updateSettings { $0.selectPreset(preset) }
                lockedRatio = settings.target.aspect
            })) {
                ForEach(OutputPreset.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .accessibilityLabel("Output preset")

            if settings.preset == .custom {
                HStack {
                    dimensionField("Width", width: true)
                    Text("×").foregroundStyle(.secondary)
                    dimensionField("Height", width: false)
                    Text("px").foregroundStyle(.secondary)
                }
                Toggle("Lock aspect ratio", isOn: $lockAspect)
                    .onChange(of: lockAspect) { _, locked in
                        if locked { lockedRatio = settings.target.aspect }
                    }
                HStack(spacing: 5) {
                    ForEach(["16:10", "16:9", "4:3", "1:1"], id: \.self) { ratio in
                        Button(ratio) {
                            let parts = ratio.split(separator: ":").compactMap { Double($0) }
                            lockedRatio = parts[0] / parts[1]
                            lockAspect = true
                            store.updateSettings {
                                $0.target.height = max(1, Int((Double($0.target.width) / lockedRatio).rounded()))
                            }
                        }.controlSize(.small)
                    }
                }
            } else {
                Text("16:10 · Mac App Store").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func dimensionField(_ title: String, width: Bool) -> some View {
        TextField(title, value: Binding(get: { width ? settings.target.width : settings.target.height }, set: { value in
            guard value != (width ? settings.target.width : settings.target.height) else { return }
            store.updateSettings {
                let bounded = max(0, min(16_385, value))
                if width {
                    $0.target.width = bounded
                    if lockAspect {
                        $0.target.height = bounded == 0 ? 0 : max(1, Int((Double(bounded) / max(0.001, lockedRatio)).rounded()))
                    }
                } else {
                    $0.target.height = bounded
                    if lockAspect {
                        $0.target.width = bounded == 0 ? 0 : max(1, Int((Double(bounded) * lockedRatio).rounded()))
                    }
                }
            }
        }), format: .number.grouping(.never))
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(title + " in pixels")
    }

    private var framing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FRAMING").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Picker("Mode", selection: binding(\.mode)) {
                ForEach(ResizeMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.labelsHidden().accessibilityLabel("Framing mode")
            Text(settings.mode.explanation).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if settings.mode != .fit {
                HStack {
                    Button("Center", systemImage: "scope") {
                        store.updateSettings { $0.focus = CGPoint(x: 0.5, y: 0.5) }
                    }
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        store.updateSettings { $0.resetFraming() }
                    }
                }
                if settings.mode == .cropAndResize {
                    Slider(value: binding(\.cropFraction), in: 0.01...1) {
                        Text("Crop area")
                    }
                    Text("Drag a corner to resize the frame.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Label("Original pixel scale", systemImage: "viewfinder")
                        .font(.caption).foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var fileOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPORT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Picker("Format", selection: binding(\.format)) {
                ForEach(OutputFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if settings.format == .jpeg {
                HStack {
                    Text("JPEG quality")
                    Spacer()
                    Text("\(Int(settings.jpegQuality * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }.font(.callout)
                Slider(value: binding(\.jpegQuality), in: 0.1...1, step: 0.01) { Text("JPEG quality") }
                    .labelsHidden()
                Text("Higher quality keeps more detail. JPEG still uses lossy compression.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Lossless compression · good for UI and text.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ColorPicker("Background", selection: Binding(get: {
                Color(red: settings.background.red, green: settings.background.green, blue: settings.background.blue)
            }, set: { color in
                guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                store.updateSettings {
                    $0.background = BackgroundColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
                }
            }), supportsOpacity: false)
            Text("Used for empty space and transparent areas. Exported as opaque, 8-bit sRGB.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
