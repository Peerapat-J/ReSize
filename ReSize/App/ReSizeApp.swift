import SwiftUI
import AppKit

@main
struct ReSizeApp: App {
    @StateObject private var store = WorkspaceStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("ReSize", id: "workspace") {
            WorkspaceView(store: store)
                // ให้ปุ่มตามสีที่เลือกไว้ใน macOS ไม่ผูกกับสีไอคอนแอป
                .tint(Color(nsColor: .controlAccentColor))
                .onAppear {
                    // เปิดไฟล์จาก Finder ได้ด้วย ถ้ามีไฟล์ส่งมาตอนแอปยังไม่พร้อมก็รับต่อที่นี่
                    appDelegate.onOpen = { store.importURLs($0) }
                    if !appDelegate.pendingURLs.isEmpty {
                        store.importURLs(appDelegate.pendingURLs)
                        appDelegate.pendingURLs = []
                    }
                }
        }
        .defaultSize(width: 1220, height: 790)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Images…", action: store.chooseImages)
                    .keyboardShortcut("o").disabled(store.isExporting || store.isImporting)
            }
            CommandGroup(after: .importExport) {
                Button("Export Image…", action: store.exportCurrent)
                    .keyboardShortcut("e").disabled(!store.canExport)
                Button("Export All Images…") { store.exportMany() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(store.items.isEmpty || store.isExporting || store.isImporting)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onOpen: (([URL]) -> Void)?
    var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        if let onOpen { onOpen(urls) } else { pendingURLs.append(contentsOf: urls) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
