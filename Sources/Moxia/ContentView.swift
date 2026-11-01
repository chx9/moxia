import SwiftUI

struct ContentView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(state: state)
            Divider().opacity(0.6)
            HSplitView {
                editorPane
                    .frame(minWidth: 380, idealWidth: 560)
                PreviewView(controller: state.preview)
                    .frame(minWidth: 440, idealWidth: 520)
                    .overlay(alignment: .bottom) { toast }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationTitle(state.title)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 用户可能在外部编辑了自定义主题
            state.reloadThemes()
            state.renderNow()
        }
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            MarkdownEditor(
                text: $state.text, font: state.editorFont, fontSize: state.editorFontSize, controller: state.editor
            ) { ratio in
                if state.syncScroll { state.preview.scroll(to: ratio) }
            }
            Divider().opacity(0.5)
            HStack(spacing: 14) {
                Text("\(state.wordCount) 字")
                Text("约 \(max(1, Int((Double(state.wordCount) / 400).rounded(.up)))) 分钟读完")
                Spacer()
                if let url = state.fileURL {
                    Text(url.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)
            .frame(height: 26)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private var toast: some View {
        if let message = state.toast {
            Label(message, systemImage: state.toastIsWarning ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct PreviewView: NSViewRepresentable {
    let controller: PreviewController

    func makeNSView(context: Context) -> NSView { controller.webView }
    func updateNSView(_ nsView: NSView, context: Context) {}
}


