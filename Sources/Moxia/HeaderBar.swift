import AppKit
import SwiftUI

/// 自绘的细窄标题栏：替代系统工具栏，标题居中，右侧放排版控件
struct HeaderBar: View {
    @Bindable var state: AppState

    static let height: CGFloat = 32
    /// 复制按钮固定使用松绿，不随文章强调色变化
    private static let copyGreen = Color(red: 0.12, green: 0.48, blue: 0.42)

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 16)

            HeaderMenu(title: state.currentTheme?.name ?? "主题", help: "文章主题") {
                Picker("文章主题", selection: $state.themeID) {
                    ForEach(state.themes.filter { !$0.isCustom }) { Text($0.name).tag($0.id) }
                    let custom = state.themes.filter(\.isCustom)
                    if !custom.isEmpty {
                        Divider()
                        ForEach(custom) { Text($0.name).tag($0.id) }
                    }
                }
                .pickerStyle(.inline)
            }

            AccentPicker(state: state)

            Button {
                state.showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HeaderButtonStyle())
            .help("常用设置")
            .popover(isPresented: $state.showSettings, arrowEdge: .bottom) {
                QuickSettingsView(state: state)
            }

            Button {
                state.copyForWeChat()
            } label: {
                Text("复制")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 24)
                    .background(Self.copyGreen, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .help("复制到公众号（⇧⌘C）")
        }
        .padding(.trailing, 12)
        .frame(height: Self.height)
        .overlay {
            // 标题居中于整个窗口；左右留白避开红绿灯与右侧控件
            DocumentTitle(state: state)
                .padding(.horizontal, 220)
        }
        .background(WindowDragArea())
        .background(Color(nsColor: .textBackgroundColor))
    }
}

/// 居中的文档标题，点击后原地重命名
private struct DocumentTitle: View {
    @Bindable var state: AppState
    @State private var isRenaming = false
    @State private var draft = ""
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        if isRenaming {
            TextField("文档名称", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(width: 220, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                )
                .focused($focused)
                .onSubmit(commit)
                .onExitCommand { isRenaming = false }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused && isRenaming { commit() }
                }
        } else {
            HStack(spacing: 6) {
                Text(state.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if state.isDirty && state.fileURL != nil {
                    Circle()
                        .fill(.tertiary)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.primary.opacity(hovering ? 0.06 : 0))
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture {
                draft = state.title
                isRenaming = true
                DispatchQueue.main.async { focused = true }
            }
            .help("点击重命名")
        }
    }

    private func commit() {
        isRenaming = false
        state.rename(to: draft)
    }
}

/// 文字 + 小箭头的轻量下拉菜单
private struct HeaderMenu<Content: View>: View {
    let title: String
    let help: String
    @ViewBuilder let content: Content

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 3) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 6)
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(HeaderButtonStyle())
        .menuIndicator(.hidden)
        .fixedSize()
        .help(help)
    }
}

/// 无边框按钮，悬停与按下时出现浅色底
struct HeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration)
    }

    private struct HoverBody: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.primary.opacity(configuration.isPressed ? 0.1 : hovering ? 0.06 : 0))
                )
                .onHover { hovering = $0 }
        }
    }
}

/// 隐藏系统标题栏后，让自绘标题栏仍可拖动窗口、双击缩放
private struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                window?.performZoom(nil)
            } else {
                window?.performDrag(with: event)
            }
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

