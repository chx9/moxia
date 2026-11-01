import AppKit
import SwiftUI

@main
struct MoxiaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let state = AppState.shared

    var body: some Scene {
        Window("墨匣", id: "main") {
            ContentView(state: state)
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 1180, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建") { state.newDocument() }
                    .keyboardShortcut("n")
                Button("打开…") { state.openDocument() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("保存") { state.save() }
                    .keyboardShortcut("s")
                Button("另存为…") { state.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            EditorCommands(editor: state.editor)
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("复制到公众号") { state.copyForWeChat() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsWindow(state: state)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 以 `swift run` 方式启动时也能获得前台窗口与菜单栏
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        MainActor.assumeIsolated { AppState.shared.open(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { AppState.shared.flushDraft() }
    }
}
