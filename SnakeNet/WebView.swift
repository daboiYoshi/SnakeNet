import SwiftUI
import WebKit

// MARK: - WebView NSViewRepresentable
struct WebView: NSViewRepresentable {
    @ObservedObject var tab: BrowserTab

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.autoresizingMask = [.width, .height]

        context.coordinator.setupObservers(for: webView)
        tab.webView = webView

        // Load home page for new tabs
        if tab.isHomePage {
            WebView.loadHomePage(webView: webView)
        } else if let url = URL(string: tab.url) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    // MARK: - Load home page (bundled HTML or fallback)
    static func loadHomePage(webView: WKWebView) {
        if let homeURL = Bundle.main.url(forResource: "home", withExtension: "html") {
            webView.loadFileURL(homeURL, allowingReadAccessTo: homeURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(fallbackHTML, baseURL: nil)
        }
    }

    static let fallbackHTML = """
    <!DOCTYPE html><html><head><meta charset="UTF-8"><title>SnakeNet Home</title>
    <style>body{margin:0;background:#0f172a;color:#e2e8f0;font-family:-apple-system,sans-serif;
    display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;gap:12px;}
    h1{font-size:36px;font-weight:800;color:#22c55e;margin:0;}p{color:#94a3b8;font-size:15px;margin:0;}
    a{color:#22c55e;text-decoration:none;}a:hover{text-decoration:underline;}</style></head>
    <body><h1>Welcome to the internet!</h1>
    <p>Search with <a href="https://search.brave.com">Brave Search</a></p>
    <p><a href="https://www.daboiyoshi.com">Snake Arcade</a> · <a href="https://docs.daboiyoshi.com">CDN Docs</a></p>
    </body></html>
    """

    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var tab: BrowserTab
        private var observations: [NSKeyValueObservation] = []

        init(tab: BrowserTab) {
            self.tab = tab
        }

        func setupObservers(for webView: WKWebView) {
            observations = [
                webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.tab.loadingProgress = wv.estimatedProgress }
                },
                webView.observe(\.title, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        let t = wv.title ?? ""
                        self?.tab.title = t.isEmpty ? "New Tab" : t
                    }
                },
                webView.observe(\.url, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if let url = wv.url {
                            let s = url.absoluteString
                            // Hide file:// paths — show home label instead
                            self.tab.url = s.hasPrefix("file://") ? "snakenet://home" : s
                        }
                    }
                },
                webView.observe(\.isLoading, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.tab.isLoading = wv.isLoading }
                },
                webView.observe(\.canGoBack, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.tab.canGoBack = wv.canGoBack }
                },
                webView.observe(\.canGoForward, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async { self?.tab.canGoForward = wv.canGoForward }
                }
            ]
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab.isLoading = false
            tab.canGoBack = webView.canGoBack
            tab.canGoForward = webView.canGoForward
            if let url = webView.url, !url.absoluteString.hasPrefix("file://") {
                tab.url = url.absoluteString
                loadFavicon(for: url)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            tab.isLoading = true
            tab.favicon = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            tab.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            tab.isLoading = false
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        private func loadFavicon(for pageURL: URL) {
            guard let host = pageURL.host else { return }
            let urlString = "https://www.google.com/s2/favicons?sz=32&domain=\(host)"
            guard let faviconURL = URL(string: urlString) else { return }
            URLSession.shared.dataTask(with: faviconURL) { [weak self] data, _, _ in
                if let data = data, let image = NSImage(data: data) {
                    DispatchQueue.main.async { self?.tab.favicon = image }
                }
            }.resume()
        }
    }
}
