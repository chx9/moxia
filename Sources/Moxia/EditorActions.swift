import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 编辑器中可插入或套用的 Markdown 结构
enum EditorAction: Int, CaseIterable, Identifiable {
    case codeBlock, table, mathBlock, imageLink, localImage, divider
    case bold, italic, inlineCode, link
    case heading1, heading2, heading3, quote, bulletList, orderedList

    var id: Int { rawValue }

    static let insertGroup: [EditorAction] = [.codeBlock, .table, .localImage, .imageLink, .mathBlock, .divider]
    static let inlineGroup: [EditorAction] = [.bold, .italic, .inlineCode, .link]
    static let headingGroup: [EditorAction] = [.heading1, .heading2, .heading3]
    static let blockGroup: [EditorAction] = [.quote, .bulletList, .orderedList]

    var title: String {
        switch self {
        case .codeBlock: "代码块"
        case .table: "表格"
        case .mathBlock: "公式"
        case .imageLink: "图片链接"
        case .localImage: "图片…"
        case .divider: "分割线"
        case .bold: "加粗"
        case .italic: "斜体"
        case .inlineCode: "行内代码"
        case .link: "链接"
        case .heading1: "一级标题"
        case .heading2: "二级标题"
        case .heading3: "三级标题"
        case .quote: "引用"
        case .bulletList: "无序列表"
        case .orderedList: "有序列表"
        }
    }

    var shortcut: KeyboardShortcut? {
        switch self {
        case .codeBlock: KeyboardShortcut("c", modifiers: [.command, .option])
        case .table: KeyboardShortcut("t", modifiers: [.command, .option])
        case .mathBlock: KeyboardShortcut("m", modifiers: [.command, .option])
        case .imageLink: KeyboardShortcut("i", modifiers: [.command, .option])
        case .divider: KeyboardShortcut("-", modifiers: [.command, .option])
        case .bold: KeyboardShortcut("b", modifiers: .command)
        case .italic: KeyboardShortcut("i", modifiers: .command)
        case .inlineCode: KeyboardShortcut("e", modifiers: [.command, .option])
        case .link: KeyboardShortcut("k", modifiers: .command)
        case .heading1: KeyboardShortcut("1", modifiers: .command)
        case .heading2: KeyboardShortcut("2", modifiers: .command)
        case .heading3: KeyboardShortcut("3", modifiers: .command)
        case .quote: KeyboardShortcut("q", modifiers: [.command, .option])
        case .bulletList: KeyboardShortcut("u", modifiers: [.command, .option])
        case .orderedList: KeyboardShortcut("o", modifiers: [.command, .option])
        case .localImage: KeyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}

/// 对编辑器文本执行插入与格式操作；通过 NSTextView 的输入接口修改，以保留撤销记录
@MainActor
final class EditorController: NSObject {
    weak var textView: NSTextView?
    /// 当前文档所在目录，用于把本地图片写成相对路径
    var documentDirectory: () -> URL? = { nil }

    func perform(_ action: EditorAction) {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)

        switch action {
        case .codeBlock:
            let code = selectedText
            insertBlock("```\n\(code)\n```", selecting: NSRange(location: 4 + code.utf16.count, length: 0))
        case .table:
            let table = """
            | 列 1 | 列 2 | 列 3 |
            | --- | --- | --- |
            |  |  |  |
            |  |  |  |
            """
            insertBlock(table, selecting: NSRange(location: 2, length: 3))
        case .mathBlock:
            let tex = selectedText.isEmpty ? "E = mc^2" : selectedText
            insertBlock("$$\n\(tex)\n$$", selecting: NSRange(location: 3, length: tex.utf16.count))
        case .imageLink:
            let alt = selectedText.isEmpty ? "图片描述" : selectedText
            let text = "![\(alt)](https://)"
            insertBlock(text, selecting: NSRange(location: alt.utf16.count + 4, length: 8))
        case .localImage:
            chooseImages()
        case .divider:
            insertBlock("---", selecting: NSRange(location: 3, length: 0))
        case .bold:
            wrap("**", "**", placeholder: "加粗文字")
        case .italic:
            wrap("*", "*", placeholder: "斜体文字")
        case .inlineCode:
            wrap("`", "`", placeholder: "code")
        case .link:
            insertLink()
        case .heading1, .heading2, .heading3:
            let level = action == .heading1 ? 1 : action == .heading2 ? 2 : 3
            toggleHeading(level)
        case .quote:
            toggleLinePrefix { _ in "> " }
        case .bulletList:
            toggleLinePrefix { _ in "- " }
        case .orderedList:
            toggleLinePrefix { "\($0 + 1). " }
        }
    }

    // MARK: 右键菜单

    func contextMenuItems() -> [NSMenuItem] {
        let insert = NSMenuItem(title: "插入", action: nil, keyEquivalent: "")
        insert.submenu = menu(groups: [EditorAction.insertGroup])
        let format = NSMenuItem(title: "格式", action: nil, keyEquivalent: "")
        format.submenu = menu(groups: [EditorAction.inlineGroup, EditorAction.headingGroup, EditorAction.blockGroup])
        return [insert, format]
    }

    private func menu(groups: [[EditorAction]]) -> NSMenu {
        let menu = NSMenu()
        for (index, group) in groups.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for action in group {
                let item = NSMenuItem(title: action.title, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
                item.target = self
                item.tag = action.rawValue
                menu.addItem(item)
            }
        }
        return menu
    }

    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        if let action = EditorAction(rawValue: sender.tag) { perform(action) }
    }

    // MARK: 基础操作

    private var string: NSString { (textView?.string ?? "") as NSString }
    private var selection: NSRange { textView?.selectedRange() ?? NSRange(location: 0, length: 0) }
    private var selectedText: String { string.substring(with: selection) }

    /// 替换指定范围，并按相对插入起点的位置设置选区
    private func replace(_ range: NSRange, with text: String, selecting relative: NSRange) {
        guard let textView else { return }
        // 每次插入单独成为一步撤销，不与前后的键入合并
        textView.breakUndoCoalescing()
        textView.insertText(text, replacementRange: range)
        textView.breakUndoCoalescing()
        textView.setSelectedRange(NSRange(location: range.location + relative.location, length: relative.length))
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    private func wrap(_ prefix: String, _ suffix: String, placeholder: String) {
        let inner = selectedText.isEmpty ? placeholder : selectedText
        replace(selection, with: prefix + inner + suffix,
                selecting: NSRange(location: prefix.utf16.count, length: inner.utf16.count))
    }

    private func insertLink() {
        let selected = selectedText
        if selected.isEmpty {
            replace(selection, with: "[链接文字](https://)", selecting: NSRange(location: 1, length: 4))
        } else {
            let text = "[\(selected)](https://)"
            replace(selection, with: text, selecting: NSRange(location: selected.utf16.count + 3, length: 8))
        }
    }

    /// 块级内容前后补足空行，保证其独立成段
    private func insertBlock(_ body: String, selecting relative: NSRange) {
        let range = selection
        let before = string.substring(to: range.location)
        let after = string.substring(from: NSMaxRange(range))
        let prefix = before.isEmpty || before.hasSuffix("\n\n") ? "" : before.hasSuffix("\n") ? "\n" : "\n\n"
        let suffix = after.hasPrefix("\n\n") ? "" : after.hasPrefix("\n") || after.isEmpty ? "\n" : "\n\n"
        replace(range, with: prefix + body + suffix,
                selecting: NSRange(location: prefix.utf16.count + relative.location, length: relative.length))
    }

    /// 对选区覆盖的每一行加上前缀；若各行都已有该前缀则移除
    private func toggleLinePrefix(_ prefix: (Int) -> String) {
        let range = string.paragraphRange(for: selection)
        var block = string.substring(with: range)
        let trailingNewline = block.hasSuffix("\n")
        if trailingNewline { block.removeLast() }

        let lines = block.components(separatedBy: "\n")
        let pattern = try! NSRegularExpression(pattern: #"^(> |[-*+] |\d+\. )"#)
        let existing = lines.map { line -> String? in
            let ns = line as NSString
            return pattern.firstMatch(in: line, range: NSRange(location: 0, length: ns.length))
                .map { ns.substring(with: $0.range) }
        }
        let alreadyApplied = lines.indices.allSatisfy { index in
            guard let current = existing[index] else { return false }
            return current == prefix(index) || (current.hasSuffix(". ") && prefix(index).hasSuffix(". "))
        }

        let result = lines.enumerated().map { index, line in
            let stripped = existing[index].map { String(line.dropFirst($0.count)) } ?? line
            return alreadyApplied ? stripped : prefix(index) + stripped
        }.joined(separator: "\n")
        let length = result.utf16.count
        replace(range, with: result + (trailingNewline ? "\n" : ""),
                selecting: lines.count > 1 ? NSRange(location: 0, length: length) : NSRange(location: length, length: 0))
    }

    private func toggleHeading(_ level: Int) {
        let range = string.paragraphRange(for: NSRange(location: selection.location, length: 0))
        var line = string.substring(with: range)
        let trailingNewline = line.hasSuffix("\n")
        if trailingNewline { line.removeLast() }

        let marks = line.prefix { $0 == "#" }.count
        let content = marks > 0 ? String(line.dropFirst(marks)).trimmingCharacters(in: .whitespaces) : line
        let result = marks == level ? content : String(repeating: "#", count: level) + " " + content
        replace(range, with: result + (trailingNewline ? "\n" : ""),
                selecting: NSRange(location: result.utf16.count, length: 0))
    }

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        insertImages(panel.urls)
    }

    // MARK: 图片

    /// 插入已存在于磁盘上的图片；位于文档目录下时写成相对路径
    func insertImages(_ urls: [URL], alt: ((URL) -> String)? = nil) {
        guard !urls.isEmpty else { return }
        let base = documentDirectory()?.standardizedFileURL.path
        let markdown = urls.map { url -> String in
            var path = url.standardizedFileURL.path
            if let base, path.hasPrefix(base + "/") { path = String(path.dropFirst(base.count + 1)) }
            let text = alt?(url) ?? url.deletingPathExtension().lastPathComponent
            // 尖括号包裹的路径允许包含空格
            return "![\(text)](<\(path)>)"
        }.joined(separator: "\n\n")
        insertBlock(markdown, selecting: NSRange(location: markdown.utf16.count, length: 0))
    }

    /// 处理粘贴板中的图片；返回 false 表示交给默认的文本粘贴
    func pasteImages(from pasteboard: NSPasteboard) -> Bool {
        let files = Self.imageFiles(in: pasteboard)
        if !files.isEmpty {
            insertImages(files)
            return true
        }
        // 同时带有文字（如从网页、文档复制）时按文字粘贴
        if pasteboard.string(forType: .string) != nil { return false }
        guard let (data, ext) = Self.imageData(in: pasteboard) else { return false }
        do {
            let url = try saveImage(data, extension: ext)
            insertImages([url]) { _ in "" }
        } catch {
            NSAlert(error: error).runModal()
        }
        return true
    }

    static func imageFiles(in pasteboard: NSPasteboard) -> [URL] {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true }
    }

    private static func imageData(in pasteboard: NSPasteboard) -> (Data, String)? {
        if let png = pasteboard.data(forType: .png) { return (png, "png") }
        if let jpeg = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.jpeg.identifier)) { return (jpeg, "jpg") }
        guard let tiff = pasteboard.data(forType: .tiff),
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return nil }
        return (png, "png")
    }

    /// 粘贴的图片保存到文档旁的 assets/；未保存的文档存入应用目录
    private func saveImage(_ data: Data, extension ext: String) throws -> URL {
        let folder = documentDirectory()?.appendingPathComponent("assets", isDirectory: true)
            ?? ThemeLibrary.customThemesURL.deletingLastPathComponent().appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stem = "image-" + formatter.string(from: Date())
        var url = folder.appendingPathComponent("\(stem).\(ext)")
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(stem)-\(index).\(ext)")
            index += 1
        }
        try data.write(to: url)
        return url
    }
}

/// 菜单栏中的「插入」与「格式」菜单
struct EditorCommands: Commands {
    let editor: EditorController

    var body: some Commands {
        CommandMenu("插入") {
            buttons(EditorAction.insertGroup)
        }
        CommandMenu("格式") {
            buttons(EditorAction.inlineGroup)
            Divider()
            buttons(EditorAction.headingGroup)
            Divider()
            buttons(EditorAction.blockGroup)
        }
    }

    private func buttons(_ actions: [EditorAction]) -> some View {
        ForEach(actions) { action in
            Button(action.title) { editor.perform(action) }
                .keyboardShortcut(action.shortcut)
        }
    }
}
