import SwiftUI

/// 埋め込み型 Web 接客を SwiftUI のレイアウト内に配置するためのビュー。
///
/// HTML 取得・スキーム解釈・読み込み完了処理は `BDashWebReception` に委譲する。
/// 配置（サイズ・位置）はホストアプリが `.frame` 等の SwiftUI API で決める。
///
/// 使用例:
/// ```swift
/// BDashEmbeddedWebReception(report: report) { event, param in
///     switch event {
///     case .EVENT_INTERNAL: handleInternalLink(param)
///     case .EVENT_WEBVIEW:  handleWebView(param)
///     }
/// }
/// .frame(height: 300)
/// ```
public struct BDashEmbeddedWebReception: View {
    private let report: BDashReport
    private let baseURL: URL?
    private let reception: BDashWebReception
    private let onEvent: ((eventType, [AnyHashable: Any]) -> Void)?

    /// - Parameters:
    ///   - report: 配信条件。
    ///   - baseURL: `loadHTMLString` に渡すベース URL。
    ///   - reception: 委譲先の `BDashWebReception`。既定で新規インスタンス。
    ///   - onEvent: Web 接客内のスキーム（internal / webview）イベント通知。
    public init(report: BDashReport,
                baseURL: URL? = nil,
                reception: BDashWebReception = BDashWebReception(),
                onEvent: ((eventType, [AnyHashable: Any]) -> Void)? = nil) {
        self.report = report
        self.baseURL = baseURL
        self.reception = reception
        self.onEvent = onEvent
    }

    public var body: some View {
        BDashEmbeddedWebReceptionView(
            report: report,
            baseURL: baseURL,
            reception: reception,
            onEvent: onEvent
        )
    }
}
