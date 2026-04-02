import SwiftUI
import WebKit

struct DashboardWebView: UIViewRepresentable {
    let jsonData: String
    var onRefresh: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(jsonData: jsonData, onRefresh: onRefresh)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Register message handler for dashboard ready callback
        config.userContentController.add(context.coordinator, name: "dashboardReady")
        config.userContentController.add(context.coordinator, name: "haptic")

        // Allow inline media playback
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Disable zoom
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0

        context.coordinator.webView = webView
        loadHTML(webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.jsonData != jsonData {
            context.coordinator.jsonData = jsonData
            injectData(webView)
        }
    }

    private func loadHTML(_ webView: WKWebView) {
        guard let htmlURL = Bundle.main.url(forResource: "dashboard", withExtension: "html") else {
            return
        }
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    private func injectData(_ webView: WKWebView) {
        let escaped = jsonData
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
        let js = "window.injectData('\(escaped)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var jsonData: String
        var onRefresh: (() -> Void)?
        weak var webView: WKWebView?

        init(jsonData: String, onRefresh: (() -> Void)?) {
            self.jsonData = jsonData
            self.onRefresh = onRefresh
        }

        // Page finished loading -> inject data
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let escaped = jsonData
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            let js = "window.injectData('\(escaped)');"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // Handle messages from JavaScript
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "dashboardReady":
                break
            case "haptic":
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            default:
                break
            }
        }
    }
}
