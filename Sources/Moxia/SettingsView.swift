import SwiftUI

// MARK: - 悬浮的常用设置

/// 标题栏齿轮弹出的常用设置，底部可进入完整设置窗口
struct QuickSettingsView: View {
    @Bindable var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsGroup("正文") {
                SettingsRow("字体") {
                    ArticleFontPicker(selection: $state.articleFont)
                }
                Divider().padding(.leading, 12)
                SettingsRow("字号") {
                    OptionalValuePicker(selection: $state.articleFontSize, options: SettingOptions.articleFontSizes, unit: "px")
                }
            }

            SettingsGroup("代码块") {
                SettingsRow("配色") {
                    CodeThemePicker(selection: $state.codeThemeID)
                }
            }

            SettingsGroup("发布") {
                SettingsRow("外链转为文末脚注") {
                    Toggle("外链转为文末脚注", isOn: $state.footnotes).labelsHidden()
                }
            }

            Divider()

            Button {
                state.showSettings = false
                openSettings()
                NSApp.activate()
            } label: {
                HStack {
                    Text("全部设置…")
                    Spacer()
                    Text("⌘,").foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
                .frame(height: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(HeaderButtonStyle())
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.system(size: 12))
        .padding(14)
        .frame(width: 280)
    }
}

// MARK: - 完整设置窗口

struct SettingsWindow: View {
    @Bindable var state: AppState
    @State private var tab = Tab.typography

    private enum Tab: String, CaseIterable, Identifiable {
        case typography = "排版", code = "代码", editor = "编辑器", general = "通用"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("分类", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, 14)

            switch tab {
            case .typography: TypographySettings(state: state)
            case .code: CodeSettings(state: state)
            case .editor: EditorSettings(state: state)
            case .general: GeneralSettings(state: state)
            }
        }
        .frame(width: 480)
        .navigationTitle("设置")
    }
}

private struct TypographySettings: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section("主题") {
                Picker("文章主题", selection: $state.themeID) {
                    ForEach(state.themes) { Text($0.name).tag($0.id) }
                }
                LabeledContent("强调色") {
                    HStack(spacing: 10) {
                        Button("跟随主题") { state.accentHex = nil }
                            .disabled(state.accentHex == nil)
                        ColorPicker("强调色", selection: $state.accentColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
            }
            Section("正文") {
                LabeledContent("字体") { ArticleFontPicker(selection: $state.articleFont) }
                LabeledContent("字号") {
                    OptionalValuePicker(selection: $state.articleFontSize, options: SettingOptions.articleFontSizes, unit: "px")
                }
                LabeledContent("行高") {
                    OptionalValuePicker(selection: $state.lineHeight, options: SettingOptions.lineHeights, unit: "")
                }
                LabeledContent("字间距") {
                    OptionalValuePicker(selection: $state.letterSpacing, options: SettingOptions.letterSpacings, unit: "px")
                }
            }
            Section {
                Toggle("两端对齐", isOn: $state.justify)
                Toggle("段落首行缩进", isOn: $state.textIndent)
            } header: {
                Text("段落")
            } footer: {
                Text("文章最终在读者的手机上显示，字体取决于对方设备；「跟随主题」表示沿用主题自身的设定。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }
}

private struct CodeSettings: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section {
                LabeledContent("配色") { CodeThemePicker(selection: $state.codeThemeID) }
                LabeledContent("字号") {
                    OptionalValuePicker(selection: $state.codeFontSize, options: SettingOptions.codeFontSizes, unit: "px")
                }
                Toggle("Mac 风格窗口", isOn: $state.macStyle)
            }
        }
        .formStyle(.grouped)
        .frame(height: 200)
    }
}

private struct EditorSettings: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section {
                Picker("字体", selection: $state.editorFont) {
                    ForEach(EditorFont.allCases) { Text($0.name).tag($0) }
                }
                LabeledContent("字号") {
                    HStack(spacing: 6) {
                        Text("\(Int(state.editorFontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Stepper("字号", value: $state.editorFontSize, in: SettingOptions.editorFontSizes, step: 1)
                            .labelsHidden()
                    }
                }
                Toggle("滚动编辑区时同步预览", isOn: $state.syncScroll)
            }
        }
        .formStyle(.grouped)
        .frame(height: 200)
    }
}

private struct GeneralSettings: View {
    @Bindable var state: AppState
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Toggle("外链转为文末脚注", isOn: $state.footnotes)
            } header: {
                Text("发布")
            } footer: {
                Text("公众号正文只允许公众号文章链接，其他链接会被移除。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("主题文件夹") {
                    HStack {
                        Button("重新载入") { state.reloadThemes(); state.renderNow() }
                        Button("打开") { state.revealThemesFolder() }
                    }
                }
            } header: {
                Text("自定义主题")
            } footer: {
                Text("放入 .css 文件即可出现在主题列表，选择器以 #moxia 开头。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("恢复所有设置为默认值") {
                    Button("恢复默认", role: .destructive) { confirmReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 380)
        .confirmationDialog("恢复所有设置为默认值？", isPresented: $confirmReset) {
            Button("恢复默认", role: .destructive) { state.resetSettings() }
        } message: {
            Text("不会影响你的文章和自定义主题文件。")
        }
    }
}

// MARK: - 共用控件

private struct ArticleFontPicker: View {
    @Binding var selection: ArticleFont

    var body: some View {
        Picker("字体", selection: $selection) {
            ForEach(ArticleFont.allCases) { Text($0.name).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
    }
}

private struct CodeThemePicker: View {
    @Binding var selection: String

    var body: some View {
        Picker("配色", selection: $selection) {
            ForEach(ThemeLibrary.codeThemes) { Text($0.name).tag($0.id) }
        }
        .labelsHidden()
        .fixedSize()
    }
}

/// nil 表示「跟随主题」
private struct OptionalValuePicker: View {
    @Binding var selection: Double?
    let options: [Double]
    let unit: String

    var body: some View {
        Picker("", selection: $selection) {
            Text("跟随主题").tag(Double?.none)
            Divider()
            ForEach(options, id: \.self) { value in
                Text(SettingOptions.format(value) + (unit.isEmpty ? "" : " \(unit)")).tag(Optional(value))
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}

/// 悬浮面板中的分组：小标题 + 浅色圆角容器
private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) { content }
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    init(_ title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
    }
}
