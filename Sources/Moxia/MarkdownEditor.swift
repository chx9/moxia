import AppKit
import SwiftUI

/// 基于 NSTextView 的 Markdown 编辑器
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var font: EditorFont
    var fontSize: CGFloat
    var controller: EditorController
    var onScroll: (Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.verticalScroller = SlimScroller()
        scrollView.scrollerStyle = .overlay
        // 接入鼠标时系统会切回常驻滚动条，这里始终保持悬浮样式
        NotificationCenter.default.addObserver(
            forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: .main
        ) { [weak scrollView] _ in
            scrollView?.scrollerStyle = .overlay
        }

        let textView = MarkdownTextView(frame: .zero)
        textView.editor = controller
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 28, height: 28)
        textView.typingAttributes = MarkdownHighlighter.baseAttributes(font: font, fontSize: fontSize)
        textView.insertionPointColor = .controlAccentColor
        textView.string = text

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
        context.coordinator.textView = textView
        controller.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let fontChanged = coordinator.parent.fontSize != fontSize || coordinator.parent.font != font
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
            // 整体替换文本后旧的撤销记录已失效，继续撤销会越界
            textView.undoManager?.removeAllActions()
            textView.scroll(.zero)
        } else if fontChanged, let storage = textView.textStorage {
            MarkdownHighlighter.highlight(storage, font: font, fontSize: fontSize)
        }
        textView.typingAttributes = MarkdownHighlighter.baseAttributes(font: font, fontSize: fontSize)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MarkdownEditor
        weak var textView: NSTextView?

        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
        }

        func textStorage(
            _ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange, changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            MarkdownHighlighter.highlight(textStorage, font: parent.font, fontSize: parent.fontSize)
        }

        func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            let items = parent.controller.contextMenuItems()
            for (index, item) in items.enumerated() { menu.insertItem(item, at: index) }
            menu.insertItem(.separator(), at: items.count)
            return menu
        }

        @objc func boundsDidChange(_ notification: Notification) {
            guard let clip = notification.object as? NSClipView, let doc = clip.documentView else { return }
            let scrollable = doc.frame.height - clip.bounds.height
            parent.onScroll(scrollable > 0 ? min(max(clip.bounds.origin.y / scrollable, 0), 1) : 0)
        }
    }
}

/// 支持粘贴、拖入图片的文本视图
final class MarkdownTextView: NSTextView {
    weak var editor: EditorController?

    override func paste(_ sender: Any?) {
        if editor?.pasteImages(from: .general) == true { return }
        super.paste(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = EditorController.imageFiles(in: sender.draggingPasteboard)
        guard let editor, !files.isEmpty else { return super.performDragOperation(sender) }
        let point = convert(sender.draggingLocation, from: nil)
        window?.makeFirstResponder(self)
        setSelectedRange(NSRange(location: characterIndexForInsertion(at: point), length: 0))
        editor.insertImages(files)
        return true
    }
}

/// 轻量的正则高亮：只调整颜色与字重，不改变文字本身
enum MarkdownHighlighter {
    static func baseAttributes(font: EditorFont, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = (fontSize * 0.47).rounded()
        return [.font: font.font(size: fontSize), .foregroundColor: NSColor.labelColor, .paragraphStyle: style]
    }

    private static let accent = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.45, green: 0.78, blue: 0.70, alpha: 1)
            : NSColor(srgbRed: 0.12, green: 0.48, blue: 0.42, alpha: 1)
    }
    private static let codeColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.93, green: 0.60, blue: 0.50, alpha: 1)
            : NSColor(srgbRed: 0.70, green: 0.29, blue: 0.21, alpha: 1)
    }

    private enum Style {
        case heading, marker, bold, italic, quote, linkText, muted, inlineCode, code, frontMatter
    }

    private struct Rule {
        let regex: NSRegularExpression
        let style: Style
        /// 仅对指定捕获组着色；nil 表示整个匹配
        var group: Int? = nil
    }

    private static func rule(_ pattern: String, _ style: Style, group: Int? = nil) -> Rule {
        Rule(regex: try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]), style: style, group: group)
    }

    private static let rules: [Rule] = [
        rule(#"^#{1,6}[ \t].*$"#, .heading),
        rule(#"^(#{1,6})[ \t]"#, .marker, group: 1),
        rule(#"\*\*[^*\n]+\*\*|__[^_\n]+__"#, .bold),
        rule(#"(?<![*\w])\*(?![\s*])[^*\n]+\*(?!\*)"#, .italic),
        rule(#"^\s*([-*+]|\d+\.)[ \t]"#, .marker, group: 1),
        rule(#"^>.*$"#, .quote),
        rule(#"!?\[([^\]\n]*)\]\(([^)\n]*)\)"#, .linkText, group: 1),
        rule(#"!?\[[^\]\n]*\]\(([^)\n]*)\)"#, .muted, group: 1),
        rule(#"`[^`\n]+`"#, .inlineCode),
        rule(#"\$\$[\s\S]*?\$\$|(?<!\$)\$(?![\s$])[^$\n]+\$"#, .code),
        rule(#"^(\*{3,}|-{3,}|_{3,})\s*$"#, .muted),
        rule(#"^```[^\n]*\n[\s\S]*?^```\s*$"#, .code),
        rule(#"\A---\n[\s\S]*?\n---$"#, .frontMatter),
    ]

    private static func attributes(for style: Style, font: EditorFont, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let mono = NSFont.monospacedSystemFont(ofSize: fontSize - 1.5, weight: .regular)
        switch style {
        case .heading: return [.font: font.font(size: fontSize + 1, weight: .bold)]
        case .marker, .linkText: return [.foregroundColor: accent]
        case .bold: return [.font: font.font(size: fontSize, weight: .semibold)]
        case .italic:
            return [.font: NSFontManager.shared.convert(font.font(size: fontSize), toHaveTrait: .italicFontMask)]
        case .quote: return [.foregroundColor: NSColor.secondaryLabelColor]
        case .muted: return [.foregroundColor: NSColor.tertiaryLabelColor]
        case .inlineCode: return [.font: mono, .foregroundColor: codeColor]
        case .code: return [.font: mono, .foregroundColor: NSColor.secondaryLabelColor]
        case .frontMatter: return [.font: mono, .foregroundColor: NSColor.tertiaryLabelColor]
        }
    }

    static func highlight(_ storage: NSTextStorage, font: EditorFont, fontSize: CGFloat) {
        let full = NSRange(location: 0, length: storage.length)
        let string = storage.string
        var cache: [Style: [NSAttributedString.Key: Any]] = [:]
        storage.setAttributes(baseAttributes(font: font, fontSize: fontSize), range: full)
        for rule in rules {
            let attrs = cache[rule.style] ?? attributes(for: rule.style, font: font, fontSize: fontSize)
            cache[rule.style] = attrs
            rule.regex.enumerateMatches(in: string, range: full) { match, _, _ in
                guard let match else { return }
                let range = rule.group.map { match.range(at: $0) } ?? match.range
                if range.location != NSNotFound { storage.addAttributes(attrs, range: range) }
            }
        }
    }
}

/// 细窄的圆角滚动条：无轨道，仅绘制半透明滑块
final class SlimScroller: NSScroller {
    private static let knobWidth: CGFloat = 6
    private static let margin: CGFloat = 3

    private static let knobColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.22)
            : NSColor.black.withAlphaComponent(0.18)
    }

    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        knobWidth + margin * 2
    }

    override func draw(_ dirtyRect: NSRect) {
        drawKnob()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        let knob = rect(for: .knob)
        guard !knob.isEmpty else { return }
        let rect = NSRect(
            x: bounds.width - Self.knobWidth - Self.margin, y: knob.minY + Self.margin,
            width: Self.knobWidth, height: max(knob.height - Self.margin * 2, Self.knobWidth)
        )
        Self.knobColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: Self.knobWidth / 2, yRadius: Self.knobWidth / 2).fill()
    }
}
