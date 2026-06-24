import SwiftUI

/// SwiftUI アプリでオーバーレイ型 Web 接客（`showMessage`）の表示状態を管理するコントローラー。
///
/// 表示・スキーム解釈・WebView 制御は SwiftUI 側で再実装せず、`BDashWebReception` に委譲する。
///
/// 使用例:
/// ```swift
/// @StateObject private var webReception = BDashWebReceptionOverlayController()
///
/// RootView()
///     .bDashWebReceptionOverlay(controller: webReception)
///     .onAppear { webReception.show(report: report) }
/// ```
@MainActor
public final class BDashWebReceptionOverlayController: ObservableObject {
    /// オーバーレイを表示中かどうか。`bDashWebReceptionOverlay` モディファイアが監視する。
    @Published public var isPresented: Bool = false

    /// ポップアップ背面のタップを下のアプリ UI へ透過させるか（配信 JSON の `allowClick`）。
    /// 値は顧客設定 API の応答後に確定するため、判明前の既定は透過（true）。
    /// 透明ホストの hitTest 挙動を切り替えるために `bDashWebReceptionOverlay` モディファイアが監視する。
    @Published public var allowClick: Bool = true

    /// 表示対象の配信条件。
    public var report: BDashReport?

    /// ポップアップのサイズ単位。`BDashWebReception.showMessage(report:onView:sizeUnit:)` にそのまま渡す。
    /// `"auto"`（既定）/ `"px"` / `"vw"` を受け付け、それ以外は Core 側で `"vw"` にフォールバックする。
    public var sizeUnit: String = "auto"

    /// Web 接客内のスキーム（internal / webview）イベントをホストへ通知するコールバック。
    public var onEvent: ((eventType, [AnyHashable: Any]) -> Void)?

    let reception: BDashWebReception

    /// - Parameter reception: 表示を委譲する `BDashWebReception`。既定で新規インスタンス。
    public init(reception: BDashWebReception = BDashWebReception()) {
        self.reception = reception
        self.reception.eventDelegate = { [weak self] type, param in
            guard let self, let event = eventType(rawValue: type) else { return }
            // param は非 Sendable。MainActor へ送るため unsafe なローカルに退避する。
            nonisolated(unsafe) let safeParam = param
            Task { @MainActor in self.onEvent?(event, safeParam) }
        }
        // ✕ ボタン・close スキーム・配信対象0件・API失敗など、いずれの経路でポップアップが
        // 閉じられた（または最初から表示されなかった）場合でも表示状態を false に戻す。
        // これを怠ると透明なオーバーレイホストがヒットテストを奪い続け、背面のスクロールが固まる。
        self.reception.onPopupClosed = { [weak self] in
            Task { @MainActor in self?.isPresented = false }
        }
        // 顧客設定 API で allowClick が確定したらホストの透過挙動へ反映する。
        self.reception.onPopupAllowClickResolved = { [weak self] allow in
            Task { @MainActor in self?.allowClick = allow }
        }
    }

    /// 指定した配信条件でオーバーレイ表示を開始する。
    /// - Parameters:
    ///   - report: 配信条件。
    ///   - sizeUnit: ポップアップのサイズ単位（`"auto"` / `"px"` / `"vw"`）。既定は `"auto"`。
    public func show(report: BDashReport, sizeUnit: String = "auto") {
        self.report = report
        self.sizeUnit = sizeUnit
        // 前回 show の allowClick を持ち越さない。確定するまでは既定（透過）に戻す。
        self.allowClick = true
        self.isPresented = true
    }

    /// 表示中のオーバーレイを閉じる。
    public func close() {
        self.isPresented = false
    }
}
