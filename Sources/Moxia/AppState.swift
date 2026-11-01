import AppKit
import Dispatch
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var text: String {
        didSet {
            guard text != oldValue else { return }
            scheduleRender()
            scheduleDraftSave()
        }
    }
    private(set) var fileURL: URL?
    /// 未保存文档的名称，首次保存时作为默认文件名
    private var untitledName: String? { didSet { persist(untitledName, "untitledName") } }
    private var savedText: String
    var isDirty: Bool { text != savedText }

    var themes: [Theme] = []
    var themeID: String {
        didSet {
            persist(themeID, "themeID")
            // 换主题时回到该主题自带的强调色，自选颜色只作用于当前主题
            if themeID != oldValue { accentHex = nil }
            watchTheme()
            renderNow()
        }
    }
    var codeThemeID: String { didSet { persist(codeThemeID, "codeThemeID"); renderNow() } }
    var accentHex: String? { didSet { persist(accentHex, "accentHex"); renderNow() } }
    var macStyle: Bool { didSet { persist(macStyle, "macStyle"); renderNow() } }
    var footnotes: Bool { didSet { persist(footnotes, "footnotes"); renderNow() } }
    var articleFont: ArticleFont { didSet { persist(articleFont.rawValue, "articleFont"); renderNow() } }
    var articleFontSize: Double? { didSet { persist(articleFontSize, "articleFontSize"); renderNow() } }
    var lineHeight: Double? { didSet { persist(lineHeight, "lineHeight"); renderNow() } }
    var letterSpacing: Double? { didSet { persist(letterSpacing, "letterSpacing"); renderNow() } }
    var justify: Bool { didSet { persist(justify, "justify"); renderNow() } }
    var textIndent: Bool { didSet { persist(textIndent, "textIndent"); renderNow() } }
    var codeFontSize: Double? { didSet { persist(codeFontSize, "codeFontSize"); renderNow() } }
    var editorFont: EditorFont { didSet { persist(editorFont.rawValue, "editorFont") } }
    var editorFontSize: Double { didSet { persist(editorFontSize, "editorFontSize") } }
    var syncScroll: Bool { didSet { persist(syncScroll, "syncScroll") } }

    var showSettings = false

    var toast: String?
    var toastIsWarning = false

    @ObservationIgnored let preview = PreviewController()
    @ObservationIgnored let editor = EditorController()
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var draftTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var themeWatcher: DispatchSourceFileSystemObject?

    private static let draftURL: URL = ThemeLibrary.customThemesURL
        .deletingLastPathComponent().appendingPathComponent("Draft.md")

    private init() {
        let defaults = UserDefaults.standard
        themeID = defaults.string(forKey: "themeID") ?? "moyun"
        codeThemeID = defaults.string(forKey: "codeThemeID") ?? "github"
        accentHex = defaults.string(forKey: "accentHex")
        macStyle = defaults.object(forKey: "macStyle") as? Bool ?? true
        footnotes = defaults.object(forKey: "footnotes") as? Bool ?? true
        articleFont = defaults.string(forKey: "articleFont").flatMap(ArticleFont.init(rawValue:)) ?? .theme
        articleFontSize = defaults.object(forKey: "articleFontSize") as? Double
        lineHeight = defaults.object(forKey: "lineHeight") as? Double
        letterSpacing = defaults.object(forKey: "letterSpacing") as? Double
        justify = defaults.bool(forKey: "justify")
        textIndent = defaults.bool(forKey: "textIndent")
        codeFontSize = defaults.object(forKey: "codeFontSize") as? Double
        editorFont = defaults.string(forKey: "editorFont").flatMap(EditorFont.init(rawValue:)) ?? .system
        editorFontSize = defaults.object(forKey: "editorFontSize") as? Double ?? 15
        syncScroll = defaults.object(forKey: "syncScroll") as? Bool ?? true

        let url = defaults.url(forKey: "fileURL").flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        fileURL = url
        untitledName = defaults.string(forKey: "untitledName")

        let fileText = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        savedText = fileText ?? ""
        if let draftText = try? String(contentsOf: Self.draftURL, encoding: .utf8) {
            text = draftText
        } else if let fileText {
            // 草稿缺失但上次的文件仍在：直接载入文件，而不是把示例文章套在文件标题下
            text = fileText
        } else {
            // 首次启动：载入示例文章，并把它视为已保存内容，避免退出时询问是否保存
            text = WelcomeArticle.text
            savedText = text
            if url == nil {
                untitledName = WelcomeArticle.name
                UserDefaults.standard.set(WelcomeArticle.name, forKey: "untitledName")
            }
        }

        reloadThemes()
        watchTheme()
        renderNow()
        editor.documentDirectory = { [weak self] in self?.fileURL?.deletingLastPathComponent() }
    }

    var title: String { fileURL?.deletingPathExtension().lastPathComponent ?? untitledName ?? "未命名" }

    /// 重命名：已保存的文档直接改磁盘上的文件名，未保存的文档仅记住名称
    func rename(to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        guard !name.isEmpty, name != title else { return }
        guard let fileURL else {
            untitledName = name
            return
        }

        let ext = fileURL.pathExtension.isEmpty ? "md" : fileURL.pathExtension
        let target = fileURL.deletingLastPathComponent().appendingPathComponent(name).appendingPathExtension(ext)
        // 仅大小写不同时视为同一文件（默认文件系统不区分大小写）
        if FileManager.default.fileExists(atPath: target.path), target.path.lowercased() != fileURL.path.lowercased() {
            let alert = NSAlert()
            alert.messageText = "“\(target.lastPathComponent)”已存在"
            alert.informativeText = "请换一个名称。"
            alert.addButton(withTitle: "好")
            alert.runModal()
            return
        }
        do {
            try FileManager.default.moveItem(at: fileURL, to: target)
            setFileURL(target)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    var currentTheme: Theme? { themes.first { $0.id == themeID } ?? themes.first }
    var currentCodeTheme: Theme? { ThemeLibrary.codeThemes.first { $0.id == codeThemeID } ?? ThemeLibrary.codeThemes.first }

    /// 当前生效的强调色：用户自选，否则取主题默认值
    var accentColor: Color {
        get {
            let hex = accentHex ?? ThemeLibrary.defaultAccent(in: ThemeLibrary.css(of: currentTheme))
            return hex.flatMap(Color.init(hex:)) ?? .accentColor
        }
        set { accentHex = newValue.hexString }
    }

    // MARK: 渲染

    func reloadThemes() {
        themes = ThemeLibrary.builtInThemes + ThemeLibrary.customThemes()
    }

    /// 监听当前主题所在目录，主题 CSS 在外部被修改后自动重绘（无需重新编译或重启）
    private func watchTheme() {
        themeWatcher?.cancel()
        themeWatcher = nil
        guard let url = currentTheme?.url else { return }

        let directory = url.deletingLastPathComponent()
        let fd = Darwin.open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .main
        )
        let name = url.lastPathComponent
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.currentTheme?.url.lastPathComponent == name else { return }
                self.scheduleRender()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        themeWatcher = source
    }

    private func scheduleRender() {
        renderTask?.cancel()
        renderTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            renderNow()
        }
    }

    func renderNow() {
        var options: [String: Any] = [
            "markdown": text,
            "themeCSS": ThemeLibrary.css(of: currentTheme),
            "codeCSS": ThemeLibrary.css(of: currentCodeTheme),
            "overrideCSS": overrideCSS,
            "macStyle": macStyle,
            "footnotes": footnotes,
        ]
        if let accentHex { options["accent"] = accentHex }
        if let dir = fileURL?.deletingLastPathComponent() { options["baseURL"] = dir.absoluteString }
        preview.render(options)
    }

    /// 用户的排版设置，叠加在文章主题与代码主题之后
    private var overrideCSS: String {
        var root: [String] = []
        if let stack = articleFont.cssStack { root.append("font-family: \(stack)") }
        if let articleFontSize { root.append("font-size: \(SettingOptions.format(articleFontSize))px") }
        if let lineHeight { root.append("line-height: \(SettingOptions.format(lineHeight))") }
        if let letterSpacing { root.append("letter-spacing: \(SettingOptions.format(letterSpacing))px") }
        if justify { root.append("text-align: justify") }

        var css = root.isEmpty ? "" : "#moxia { \(root.joined(separator: "; ")); }\n"
        if textIndent { css += "#moxia > p { text-indent: 2em; }\n" }
        if let codeFontSize { css += "#moxia pre { font-size: \(SettingOptions.format(codeFontSize))px; }\n" }
        return css
    }

    func resetSettings() {
        themeID = "moyun"
        codeThemeID = "github"
        accentHex = nil
        macStyle = true
        footnotes = true
        articleFont = .theme
        articleFontSize = nil
        lineHeight = nil
        letterSpacing = nil
        justify = false
        textIndent = false
        codeFontSize = nil
        editorFont = .system
        editorFontSize = 15
        syncScroll = true
    }

    // MARK: 复制到公众号

    func copyForWeChat() {
        Task {
            renderTask?.cancel()
            renderNow()
            try? await Task.sleep(for: .milliseconds(50))
            guard let output = await preview.output() else {
                showToast("没有可复制的内容")
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            // 补全 charset，避免粘贴到浏览器时中文乱码
            let html = "<html><head><meta charset=\"utf-8\"></head><body>\(output.html)</body></html>"
            pasteboard.setString(html, forType: .html)
            pasteboard.setString(output.text, forType: .string)
            if output.localImages > 0 {
                showToast("已复制 · \(output.localImages) 张本地图片已替换为占位框，请在公众号中补图", warning: true)
            } else {
                showToast("已复制，可直接粘贴到公众号编辑器")
            }
        }
    }

    func showToast(_ message: String, warning: Bool = false) {
        toastTask?.cancel()
        toastIsWarning = warning
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(warning ? 4 : 2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) { toast = nil }
        }
    }

    // MARK: 文件

    func newDocument() {
        guard confirmDiscardChanges() else { return }
        load(text: "", from: nil)
    }

    func openDocument() {
        guard confirmDiscardChanges() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.markdownTypes
        guard panel.runModal() == .OK, let url = panel.url else { return }
        read(url)
    }

    /// 从 Finder、Dock 或 `open` 命令打开文件
    func open(_ url: URL) {
        guard url.standardizedFileURL != fileURL?.standardizedFileURL || !isDirty else { return }
        guard confirmDiscardChanges() else { return }
        read(url)
    }

    private func read(_ url: URL) {
        do {
            load(text: try String(contentsOf: url, encoding: .utf8), from: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @discardableResult
    func save() -> Bool {
        guard let fileURL else { return saveAs() }
        return write(to: fileURL)
    }

    @discardableResult
    func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.markdownTypes[0]]
        panel.nameFieldStringValue = title + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return write(to: url)
    }

    func revealThemesFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([ThemeLibrary.customThemesURL])
    }

    private func write(to url: URL) -> Bool {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            setFileURL(url)
            savedText = text
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }

    private func load(text newText: String, from url: URL?) {
        setFileURL(url)
        savedText = newText
        text = newText
        renderNow()
    }

    private func setFileURL(_ url: URL?) {
        fileURL = url
        untitledName = nil
        UserDefaults.standard.set(url, forKey: "fileURL")
    }

    /// 返回 false 表示用户取消
    private func confirmDiscardChanges() -> Bool {
        guard isDirty, !text.isEmpty else { return true }
        let alert = NSAlert()
        alert.messageText = "要保存对“\(title)”的修改吗？"
        alert.informativeText = "如果不保存，你的修改将会丢失。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "不保存")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save()
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }

    /// 首次启动的示例文章没有被改动过，不必写进草稿
    private var isPristineExample: Bool {
        fileURL == nil && text == WelcomeArticle.text
    }

    private func scheduleDraftSave() {
        draftTask?.cancel()
        guard !isPristineExample else { return }
        draftTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            try? text.write(to: Self.draftURL, atomically: true, encoding: .utf8)
        }
    }

    func flushDraft() {
        guard !isPristineExample else { return }
        try? text.write(to: Self.draftURL, atomically: true, encoding: .utf8)
    }

    private func persist(_ value: Any?, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static let markdownTypes: [UTType] = [
        UTType("net.daringfireball.markdown") ?? .plainText, .plainText,
    ]
}

// MARK: - 字数统计

extension AppState {
    /// 中日韩字符逐字计数，拉丁字母与数字按词计数
    var wordCount: Int {
        var count = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x3040...0x30FF, 0xAC00...0xD7AF, 0xF900...0xFAFF:
                count += 1
                inWord = false
            default:
                let isWordChar = CharacterSet.alphanumerics.contains(scalar)
                if isWordChar && !inWord { count += 1 }
                inWord = isWordChar
            }
        }
        return count
    }
}

// MARK: - 颜色转换

extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard value.count == 6, let n = UInt32(value, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((n >> 16) & 0xFF) / 255, green: Double((n >> 8) & 0xFF) / 255, blue: Double(n & 0xFF) / 255
        )
    }

    var hexString: String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let channel = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", channel(c.redComponent), channel(c.greenComponent), channel(c.blueComponent))
    }
}
