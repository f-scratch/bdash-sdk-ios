import SwiftUI

/// SwiftUI アプリでフォアグラウンド Push 通知アラートの表示状態を管理するコントローラー。
///
/// ペイロード解析・アラート UI は SwiftUI 側で再実装せず、既存の UIKit/Core 実装に委譲する。
/// - ペイロード→表示コンテンツ変換: `BDashNotification.createAlertContents(from:)`
/// - アラート UI: `BDashAlertViewController` / `BDashDoubleButtonAlertViewController`
///
/// 使用例:
/// ```swift
/// @StateObject private var alert = BDashPushAlertController()
///
/// RootView()
///     .bDashPushAlert(controller: alert)
///     .onReceive(remotePushPublisher) { userInfo in
///         // OS設定で通知OFFのときは表示を抑止する（推奨）
///         Task { await alert.presentIfAuthorized(userInfo: userInfo) }
///     }
/// ```
@MainActor
public final class BDashPushAlertController: ObservableObject {
    /// アラートが表示中かどうか。`bDashPushAlert` モディファイアが監視する。
    @Published public var isPresented: Bool = false

    /// 表示するアラートの内容。`createAlertContents(from:)` の結果を保持する（内部利用）。
    @Published var contents: BDashAlertViewContents?

    /// 非同期取得したフォールバック画像。ホストが表示中アラートへ後差し込みするために監視する（内部利用）。
    @Published var lateImage: UIImage?

    private let notification: BDashNotification

    /// - Parameter notification: コンテンツ変換を委譲する `BDashNotification`。既定では共有インスタンス。
    public init(notification: BDashNotification = BDashNotification.getInstance()) {
        self.notification = notification
    }

    /// Push 通知のペイロード（`userInfo`）からアラートを表示する。
    ///
    /// ペイロードの解析（fcm_api v1/legacy、aps/notification、ボタン配列、画像等）は
    /// `BDashNotification.createAlertContents(from:)` に委譲する。
    ///
    /// フォアグラウンドでは Host の
    /// `userNotificationCenter(_:willPresent:withCompletionHandler:)` で受け取った
    /// `notification.request.content.userInfo` を渡して呼び出す。
    /// `_sharedMediaPath` が無くても payload の画像URLから画像を非同期取得して反映する。
    ///
    /// OS設定で通知が OFF のときは OS の最新の許可状態を確認してアラート表示を抑止する（推奨経路）。
    /// - Parameter userInfo: `willPresent` 等で受け取る通知ペイロード。
    public func presentIfAuthorized(userInfo: [AnyHashable: Any]) async {
        guard await notification.refreshNotificationAuthorized() else { return }
        present(userInfo: userInfo)
    }

    /// フォアグラウンドでは Host の
    /// `userNotificationCenter(_:willPresent:withCompletionHandler:)` で受け取った
    /// `notification.request.content.userInfo` を渡して呼び出す。
    /// `_sharedMediaPath` が無くても payload の画像URLから画像を非同期取得して反映する。
    ///
    /// OS設定で通知が OFF のとき（キャッシュ値で判定）はアラートを表示しない。最新の
    /// 許可状態で判定したい場合は `presentIfAuthorized(userInfo:)` を使うこと。
    /// - Parameter userInfo: `willPresent` 等で受け取る通知ペイロード。
    public func present(userInfo: [AnyHashable: Any]) {
        // OS設定で通知が OFF のときは SDK 独自アラートを表示しない（キャッシュ値で判定）
        guard notification.isNotificationAuthorizedCached else { return }
        let contents = notification.createAlertContents(from: userInfo)
        self.contents = contents
        self.lateImage = nil
        self.isPresented = true

        // フォアグラウンドで _sharedMediaPath が無い場合は payload URL から画像を非同期取得する
        if contents.image == nil, let urlString = contents.fallbackImageURLString {
            // 取得完了時に表示中の contents が入れ替わっていないか識別するためのトークン（Sendable）
            let token = ObjectIdentifier(contents)
            notification.fetchFallbackImage(urlString: urlString) { [weak self] image in
                guard let self = self, let image = image else { return }
                // 取得完了が表示中の contents に対するものか確認してから反映
                guard let current = self.contents, ObjectIdentifier(current) == token else { return }
                self.lateImage = image
            }
        }
    }

    /// 表示中のアラートを閉じる。
    public func dismiss() {
        self.isPresented = false
    }
}
