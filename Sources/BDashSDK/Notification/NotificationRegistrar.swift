import Foundation
import UIKit

/// Push通知トークンの登録・解除のコアロジック
/// HTTPClient を利用したサーバーへのトークン登録・解除処理
///
/// Firebase の初期化・MessagingDelegate 設定・通知許可ダイアログ表示・APNs/FCMトークン取得は
/// すべてホストアプリの責務。ホストアプリは取得した FCM トークン文字列を
/// `BDashNotification.getInstance().setFcmToken(fcmToken:)` でSDKに渡すこと。
@objcMembers
public final class NotificationRegistrar: NSObject, Sendable {

    /// 端末の通知ON/OFF設定
    nonisolated(unsafe) private var notificationSettingStatus: Bool = false {
        didSet {
            Task { @MainActor in
                BDashLogger.debug("updated: notificationSettingStatus is \(notificationSettingStatus)")
            }
        }
    }

    /// サーバー同期状況ステータス
    public nonisolated(unsafe) var serverResponseStatus: String = BDashNotification.PROHIBIT

    fileprivate class var sharedInstance: NotificationRegistrar {
        struct Static {
            static let instance: NotificationRegistrar = NotificationRegistrar()
        }
        return Static.instance
    }

    public class func getInstance() -> NotificationRegistrar {
        let registrar = NotificationRegistrar.sharedInstance
        return registrar
    }

    nonisolated(unsafe) private var progressTokenRequestCompletion : (@Sendable (_ type:String,_ notificationId:String?,_ response:Data?) -> Void)? = nil
    nonisolated(unsafe) private var cancelTokenRequestCompletion : (@Sendable (_ type:String,_ notificationId:String?,_ response:Data?) -> Void)? = nil

    public override init() {
        super.init()
        defer {
            // シングルトンの初期化処理の呼出を保証
            _ = BDashNotification.getInstance()
        }
    }

    /// トークン登録のサーバー同期メソッド
    public func registerToken() async throws {
        BDashLogger.debug("start registerToken()")
        // 端末設定が通知OFFの場合は登録同期しない
        if await extractNotificationSettingStatus() == false {
            BDashLogger.debug("canceled: registerToken() because notification is denied or not determined")
            return
        }
        // FCMトークン値がnilの場合は登録同期しない
        guard let token = BDashNotification.getInstance().getFcmToken() else {
            BDashLogger.debug("canceled: registerToken() because fcm token is nil")
            BDashLogger.debug("hint: host app must call BDashNotification.getInstance().setFcmToken(_:) after receiving the FCM token from MessagingDelegate")
            return
        }
        BDashLogger.debug("prepared fcmToken for server sync: \(String(describing: token))")
        let beforeServerResponse = self.getLastServerResponseStatus()
        self.progressTokenRequestCompletion = {(type, notificationId, response) in
            Task { @MainActor in
                BDashLogger.debug("[register] type: \(beforeServerResponse) -> \(type)")
                BDashLogger.debug("[register] notificationId: \(notificationId ?? "nil")")
                if let res = response {
                    BDashLogger.debug("[register] response: \(res)")
                }
                self.serverResponseStatus = type
                BDashLogger.debug("end registerToken()")
            }
        }

        do {
            try BDashNotification.getInstance().registerNotification(completion: self.progressTokenRequestCompletion)
        } catch BDashNotification.BDashException.BDashBusyException {
            BDashLogger.debug("catched: BDashBusyException at registerToken()")
            BDashLogger.debug("canceled: registerToken()")
        }
    }

    /// トークン解除のサーバー同期メソッド
    public func cancelToken() async throws {
        BDashLogger.debug("start cancelToken()")
        // 端末設定が通知ONの場合は解除同期しない
        if await extractNotificationSettingStatus() {
            BDashLogger.debug("canceled: cancelToken() because notification is authorized")
            return
        }
        let beforeServerResponse = self.getLastServerResponseStatus()
        self.cancelTokenRequestCompletion = {(type, notificationId, response) in
            Task { @MainActor in
                BDashLogger.debug("[cancel] type: \(beforeServerResponse) -> \(type)")
                BDashLogger.debug("[cancel] notificationId: \(notificationId ?? "nil")")
                if let res = response {
                    BDashLogger.debug("[cancel] response: \(res)")
                }
                self.serverResponseStatus = type
                BDashLogger.debug("end cancelToken()")
            }
        }
        BDashNotification.getInstance().setFcmToken(fcmToken: nil)

        do {
            try BDashNotification.getInstance().cancelNotification(completion: self.cancelTokenRequestCompletion)
        } catch BDashNotification.BDashException.BDashBusyException {
            BDashLogger.debug("catched: BDashBusyException at cancelToken()")
            BDashLogger.debug("canceled: cancelToken()")
        }
    }

    /// 端末の通知ON/OFF設定を取得し、トークンの登録/解除を判別して同期するメソッド
    public func syncWithNotificationSetting() async {
        BDashLogger.debug("start syncWithNotificationSetting()")

        // 端末の通知ON/OFF設定を取得更新
        self.notificationSettingStatus = await self.extractNotificationSettingStatus()
        // サーバーの最終ステータスを取得更新
        self.serverResponseStatus = self.getLastServerResponseStatus()

        BDashLogger.debug("notification: \(self.notificationSettingStatus), Server: \(self.serverResponseStatus)")

        if self.notificationSettingStatus {
            // 端末設定が通知ONの時
            switch self.serverResponseStatus {
            case BDashNotification.PROHIBIT:
                BDashLogger.debug("need sync")
                try? await self.registerToken()
                break
            case BDashNotification.ENABLE:
                BDashLogger.debug("no need sync")
                break
            case BDashNotification.DISABLE:
                BDashLogger.debug("need sync")
                try? await self.registerToken()
                break
            case BDashNotification.BUSY:
                break
            case BDashNotification.ERROR:
                BDashLogger.debug("need sync")
                try? await self.registerToken()
                break
            default:
                break
            }
        } else {
            // 端末設定が通知OFFの時
            switch self.serverResponseStatus {
            case BDashNotification.PROHIBIT:
                BDashLogger.debug("need sync")
                try? await self.cancelToken()
                break
            case BDashNotification.ENABLE:
                BDashLogger.debug("need sync")
                try? await self.cancelToken()
                break
            case BDashNotification.DISABLE:
                BDashLogger.debug("no need sync")
                break
            case BDashNotification.BUSY:
                break
            case BDashNotification.ERROR:
                BDashLogger.debug("need sync")
                try? await self.cancelToken()
                break
            default:
                break
            }
        }

        BDashLogger.debug("end syncWithNotificationSetting()")
    }

    /// 端末の通知ON/OFF設定を取得する
    public func extractNotificationSettingStatus() async -> Bool {
        var status: Bool = false
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            status = true
        case .denied:
            status = false
        case .notDetermined:
            status = false
        default:
            status = false
        }
        return status
    }

    /// 一番最後にサーバーに同期したFCMトークン値に更新する
    public func pullLastServerSyncToken() {
        let beforeToken = BDashNotification.getInstance().getFcmToken() ?? "nil"
        BDashNotification.getInstance().setFcmToken(fcmToken: BDashNotification.lastSyncTokenId)
        let afterToken = BDashNotification.getInstance().getFcmToken() ?? "nil"
        BDashLogger.debug("before FCMToken: \(beforeToken)")
        BDashLogger.debug("after FCMToken: \(afterToken)")
    }

    /// 端末の通知設定を渡す
    public func getNotificationSettingStatus() -> Bool {
        return self.notificationSettingStatus
    }

    /// 最後のサーバーレスポンスの同期ステータス値を取得
    private func getLastServerResponseStatus() -> String {
        return BDashNotification.getInstance().getLastServerResponseStatus()
    }
}
