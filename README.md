# bdash-sdk-ios-dev

## フォアグラウンドでのPush通知連携

本SDKは Firebase 非依存です。`UNUserNotificationCenter.current().delegate` の保持は
ホストアプリ側の責務とし、SDK は delegate を奪いません。フォアグラウンドで通知を受け取った際は、
ホストの `willPresent` から SDK の入口メソッドを呼んでください。

リッチPush（画像付き）のフォアグラウンド表示では、`_sharedMediaPath`（NSEが書き込む共有パス）が
取得できない場合でも、SDK が payload の画像URL（fcm v1: `fcm_options.image` / legacy: `mediaUrl`）から
画像を非同期取得し、表示中のアラートへ後から差し込みます。テキストは即時表示されます。

### UIKit

```swift
import UserNotifications
import BDashSDK

extension AppDelegate: UNUserNotificationCenterDelegate {
    // フォアグラウンド受信
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            let options = await BDashNotification.getInstance().willPresentNotification(notification)
            completionHandler(options)
        }
    }
}
```

`willPresentNotification(_:)`（async 版）は OS の通知許可状態を確認し、**許可されている場合のみ**
SDK 独自のリッチアラートを表示します。OS設定で通知が OFF（`.denied` / `.notDetermined`）のときは
アラートを表示せず空の options を返します。表示する場合は OS 標準バナーは抑止しつつ
音・バッジ（`[.sound, .badge]`）を返します。バッジ更新等の silent payload（`aps.alert` 無し）も
アラートを表示せず空の options を返します。

> 後方互換のため同期版 `willPresentNotification(_:) -> UNNotificationPresentationOptions` も
> 残していますが、こちらは直近に取得した許可状態のキャッシュ値で判定するため、最新の許可状態で
> 判定したい場合は上記の async 版を使用してください。

### SwiftUI

```swift
import SwiftUI
import BDashSDK

@StateObject private var alert = BDashPushAlertController()

var body: some View {
    RootView()
        .bDashPushAlert(controller: alert)
        // willPresent で受け取った userInfo を publish して present する
        .onReceive(foregroundPushPublisher) { userInfo in
            // OS設定で通知OFFのときは表示を抑止する（推奨）
            Task { await alert.presentIfAuthorized(userInfo: userInfo) }
        }
}
```

`AppDelegate`（`@UIApplicationDelegateAdaptor`）の `willPresent` で
`notification.request.content.userInfo` を取り出し、上記 publisher 等で
`alert.presentIfAuthorized(userInfo:)` に渡してください。`presentIfAuthorized(userInfo:)` は
OS の通知許可状態を確認し、OFF のときはアラートを表示しません。同期版 `present(userInfo:)` も
残していますが、こちらはキャッシュ値で判定します。

### リッチPush（ロック画面/バナー）には Notification Service Extension が必要

ロック画面やバナーに画像を表示するには、ホストアプリに
`BDashNotificationServiceExtension` ターゲットを追加してください。
フォアグラウンドのアプリ内アラート画像は、NSE が無くても SDK が取得して表示します。
