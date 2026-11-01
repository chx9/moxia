import Foundation

struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    var isCustom = false
}

/// 内置主题、代码高亮主题与用户自定义主题（~/Library/Application Support/Moxia/Themes/*.css）
enum ThemeLibrary {
    static let rendererURL: URL = {
        // 开发时优先读取源码目录，改主题 CSS 后无需重新编译
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Renderer")
        if FileManager.default.fileExists(atPath: source.path) { return source }
        // 打包后的 .app 将资源放在 Contents/Resources；`swift run` 时退回 SwiftPM 资源包
        if let url = Bundle.main.url(forResource: "Renderer", withExtension: nil) { return url }
        return Bundle.module.url(forResource: "Renderer", withExtension: nil)!
    }()

    static let customThemesURL: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Moxia/Themes", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let builtInThemes: [Theme] = [
        ("moyun", "墨韵"), ("sujian", "素笺"), ("qingkong", "晴空"), ("shiguang", "拾光"), ("gelv", "格律"), ("jiaotang", "焦糖"), ("shiping", "时评"), ("manfu", "慢富"),
    ].map { Theme(id: $0.0, name: $0.1, url: rendererURL.appendingPathComponent("themes/\($0.0).css")) }

    static let codeThemes: [Theme] = [
        ("github", "GitHub"), ("atom-one-light", "One Light"), ("xcode", "Xcode"),
        ("github-dark", "GitHub Dark"), ("atom-one-dark", "One Dark"), ("nord", "Nord"), ("vs2015", "VS 2015"),
    ].map { Theme(id: $0.0, name: $0.1, url: rendererURL.appendingPathComponent("code/\($0.0).css")) }

    static func customThemes() -> [Theme] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: customThemesURL, includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == "css" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { Theme(id: "custom:" + $0.lastPathComponent, name: $0.deletingPathExtension().lastPathComponent, url: $0, isCustom: true) }
    }

    static func css(of theme: Theme?) -> String {
        guard let theme else { return "" }
        return (try? String(contentsOf: theme.url, encoding: .utf8)) ?? ""
    }
}

extension ThemeLibrary {
    /// 主题 CSS 中声明的 `--accent` 默认值
    static func defaultAccent(in css: String) -> String? {
        guard let match = css.firstMatch(of: #/--accent\s*:\s*(\#[0-9a-fA-F]{6})/#) else { return nil }
        return String(match.1)
    }
}
