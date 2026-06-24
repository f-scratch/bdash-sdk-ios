import SwiftUI
import WebKit

/// 埋め込み型 Web 接客を表示する `WKWebView` の SwiftUI ラッパー（内部実装）。
///
/// HTML の取得は `BDashWebReception.getWebReception(report:onView:)`、スキーム解釈と
/// 読み込み完了処理は `performEachSchemeInEmbedding(url:)` /
/// `performFinishProcessInEmbedding(statusCode:webView:)` に委譲する。
/// SwiftUI 側でスキーム解析や HTML 取得ロジックを再実装しない。
struct BDashEmbeddedWebReceptionView: UIViewRepresentable {
    let report: BDashReport
    let baseURL: URL?
    let reception: BDashWebReception
    let onEvent: ((eventType, [AnyHashable: Any]) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(report: report, baseURL: baseURL, reception: reception, onEvent: onEvent)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.load(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let report: BDashReport
        private let baseURL: URL?
        private let reception: BDashWebReception
        private let onEvent: ((eventType, [AnyHashable: Any]) -> Void)?
        private var statusCode: Int = 200
        private var didLoad = false

        init(report: BDashReport,
             baseURL: URL?,
             reception: BDashWebReception,
             onEvent: ((eventType, [AnyHashable: Any]) -> Void)?) {
            self.report = report
            self.baseURL = baseURL
            self.reception = reception
            self.onEvent = onEvent
            super.init()
            // getWebReceptionEventDelegate は @Sendable クロージャのため、非 Sendable な onEvent を
            // 直接キャプチャできない。MainActor 隔離された自身経由でイベントを転送する。
            self.reception.getWebReceptionEventDelegate = { [weak self] type, param in
                guard let event = eventType(rawValue: type) else { return }
                // param は非 Sendable。MainActor へ送るため unsafe なローカルに退避する。
                nonisolated(unsafe) let safeParam = param
                Task { @MainActor in self?.onEvent?(event, safeParam) }
            }
        }

        /// HTML 取得（Core 委譲）→ WebView へロード。一度だけ実行する。
        func load(into webView: WKWebView) {
            guard !didLoad else { return }
            didLoad = true
            Task { @MainActor in
                let html = await reception.getWebReception(report: report, onView: webView)
                webView.loadHTMLString(html, baseURL: baseURL)
            }
        }

        // 以下、UIKit 版 `WebReceptionViewController` の WKNavigationDelegate 実装を踏襲（Core へ委譲）。

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                _ = await reception.performEachSchemeInEmbedding(url: webView.url)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
            guard let httpURLResponse = navigationResponse.response as? HTTPURLResponse else {
                decisionHandler(.allow)
                return
            }
            self.statusCode = httpURLResponse.statusCode
            decisionHandler(statusCode == 200 ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                await reception.performFinishProcessInEmbedding(statusCode: statusCode, webView: webView)
            }
        }
    }
}
