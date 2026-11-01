import Foundation

/// 首次启动时展示的示例文章。
///
/// 内容来自仓库根目录的 `Examples/welcome.md`：开发时直接读取源码，
/// 打包后由 `scripts/build-app.sh` 复制到 `Contents/Resources/Examples`。
enum WelcomeArticle {
    static let name = "欢迎使用墨匣"

    static let text: String = {
        if let url = fileURL, let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        return fallback
    }()

    private static var fileURL: URL? {
        // 源码目录：Examples 与 Sources 同级，修改后重启应用即可生效
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../Examples/welcome.md")
            .standardizedFileURL
        if FileManager.default.fileExists(atPath: source.path) { return source }

        return Bundle.main.url(forResource: "welcome", withExtension: "md", subdirectory: "Examples")
    }

    private static let fallback = """
    # 欢迎使用墨匣

    为微信公众号而生的 Markdown 排版工具。在左侧书写 Markdown，右侧预览，点击「复制」后直接粘贴到公众号后台。
    """
}
