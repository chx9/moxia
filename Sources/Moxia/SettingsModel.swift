import AppKit

/// 正文字体：最终由读者设备渲染，因此只提供各平台普遍具备的字体族
enum ArticleFont: String, CaseIterable, Identifiable {
    case theme, sans, serif, kai

    var id: String { rawValue }

    var name: String {
        switch self {
        case .theme: "跟随主题"
        case .sans: "无衬线"
        case .serif: "宋体"
        case .kai: "楷体"
        }
    }

    var cssStack: String? {
        switch self {
        case .theme: nil
        case .sans: #"-apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Helvetica Neue", Arial, sans-serif"#
        case .serif: #""Songti SC", "Noto Serif SC", "Source Han Serif SC", STSong, SimSun, Georgia, serif"#
        case .kai: #""Kaiti SC", STKaiti, KaiTi, "Songti SC", serif"#
        }
    }
}

/// 编辑器字体
enum EditorFont: String, CaseIterable, Identifiable {
    case system, serif, mono

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: "系统"
        case .serif: "衬线"
        case .mono: "等宽"
        }
    }

    func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self {
        case .system:
            return .systemFont(ofSize: size, weight: weight)
        case .serif:
            // 直接使用宋体：若以西文衬线体为主、中文回退，标点会混用西文字形而间距失衡
            let traits: NSFontTraitMask = weight.rawValue >= NSFont.Weight.semibold.rawValue ? .boldFontMask : []
            return NSFontManager.shared.font(withFamily: "Songti SC", traits: traits, weight: 5, size: size)
                ?? .systemFont(ofSize: size, weight: weight)
        case .mono:
            return .monospacedSystemFont(ofSize: size - 1, weight: weight)
        }
    }
}

/// 可选数值设置的候选项（nil 即跟随主题）
enum SettingOptions {
    static let articleFontSizes: [Double] = [14, 15, 16, 17, 18]
    static let lineHeights: [Double] = [1.6, 1.75, 1.9, 2.0, 2.2]
    static let letterSpacings: [Double] = [0, 0.5, 1, 1.5, 2]
    static let codeFontSizes: [Double] = [12, 13, 14]
    static let editorFontSizes: ClosedRange<Double> = 12...22

    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
