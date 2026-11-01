import AppKit
import WebKit

/// 持有预览用的 WKWebView，并作为 Swift 与渲染核心（moxia.js）之间的桥
@MainActor
final class PreviewController: NSObject, WKNavigationDelegate {
    struct Output {
        let html: String
        let text: String
        let localImages: Int
    }

    let webView: WKWebView
    private var isLoaded = false
    private var pending: [String: Any]?
    private var isRendering = false

    override init() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        super.init()
        webView.navigationDelegate = self

        let index = ThemeLibrary.rendererURL.appendingPathComponent("index.html")
        // 授予根目录读取权限，以便预览文章中引用的本地图片
        webView.loadFileURL(index, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    /// 合并高频调用：渲染进行中时只保留最新一次请求
    func render(_ options: [String: Any]) {
        pending = options
        guard isLoaded, !isRendering else { return }
        Task { await drain() }
    }

    private func drain() async {
        isRendering = true
        defer { isRendering = false }
        while let options = pending {
            pending = nil
            do {
                _ = try await webView.callAsyncJavaScript(
                    "return await moxia.render(options)", arguments: ["options": options], contentWorld: .page
                )
            } catch {
                NSLog("Moxia render failed: \(error)")
            }
        }
    }

    func output() async -> Output? {
        guard isLoaded,
              let result = try? await webView.callAsyncJavaScript(
                  "return moxia.getOutput()", arguments: [:], contentWorld: .page
              ) as? [String: Any],
              let html = result["html"] as? String, !html.isEmpty
        else { return nil }
        return Output(html: html, text: result["text"] as? String ?? "", localImages: result["localImages"] as? Int ?? 0)
    }

    func scroll(to ratio: Double) {
        guard isLoaded else { return }
        webView.evaluateJavaScript("moxia.scrollTo(\(ratio))")
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        if pending != nil { Task { await drain() } }
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        if action.navigationType == .linkActivated, let url = action.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
