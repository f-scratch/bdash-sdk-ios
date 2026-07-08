import Foundation

public struct BDashConst: Sendable {

    ///同時に発生するトランザクション数　（非同期でできる処理本数を規定する。）
    public static let kTransactionMax = 10
    ///テーブル内最大所持件数を定義
    public static let kTrackingMaxData:UInt = 1000
    
    ///リクエスト毎最大所持件数を定義
    public static let kRequestPerCountMax:UInt = 100
    ///リクエスト毎のレコード件数(send)
    public static let kRequestPerCount:UInt = 10
    
    ///リクエスト毎のレコード件数(sync)
    public static let kRequestPerCountForSync:UInt = 1
    
    // 添付画像のサイズ上限。10MB を超える画像は添付せず、画像なしの通常通知として配信する。
    public static let kMaxImageAttachmentByteSize: Int = 1000 * 1000 * 10
    ///リクエスト応答時間リミット
    public static let kRequestPerLimitTime: TimeInterval = 30
    //kServerUrl:要求serverUrl
    ///本番環境URL（v2エンドポイント）
    public static let kServerUrl:String = "https://trackersdk.smart-bdash.com/v2/tracking"
    ///本番環境 トークン処理API（v2エンドポイント）
    public static let kPushNotifyTokenApiUrl:String = "https://mobile.smart-bdash.com/v2/notification"

    ///固定文字列：enableSoundForPushNotification
    public static let kEnableSoundForPushNotification:String = "enableSoundForPushNotification"
    ///固定文字列：enableVibelateForPushNotification
    public static let kEnableViblateForPushNotification:String = "enableVibelateForPushNotification"
    ///固定文字列：systemSoundFileNameForPushNotification
    public static let kSystemSoundFileNameForPushNotification:String = "SystemSoundFileNameForPushNotification"
    ///固定文字列：LastServerResponseStatus
    public static let kLastServerResponseStatus:String = "LastServerResponseStatus"
    ///固定文字列：lastSyncTokenId
    public static let kLastSyncTokenId:String = "LastSyncTokenId"
    ///固定文字列：PushNotificationSerialQueueRun
    public static let kPushNotificationSerialQueueRun:String = "PushNotificationSerialQueueRun"
    ///固定文字列：PushNotificationSerialQueueStack
    public static let kPushNotificationSerialQueueStack:String = "PushNotificationSerialQueueStack"
    
    ///固定文字列：event
    public static let kInternalTypeEvent:String = "event"
    ///固定文字列：screenview
    public static let kInternalTypeScreen:String = "screenview"
    ///固定文字列：exception
    public static let kInternalTypeCrash:String = "exception"
    ///固定文字列：Bdash
    public static let kBaseUserDefaultsKey:String = "Bdash"
    ///固定文字列：com.tracking.mobile
    public static let kTrackingDomain:String = "com.tracking.mobile"
    ///固定文字列：com.f_scratch.bdash.mobile.download.image
    // BDashNotificationService.swift で定義しているものと同一
    public static let kDownloadImageDomain:String = "com.f_scratch.bdash.mobile.download.image"
    ///固定文字列：BDashTrackingData
    public static let kEntityName:String = "BDashTrackingData"
    ///固定文字列：com.f_scratch.bdash.mobile.analytics.CoreData
    public static let kSqliteDirName:String = "com.f_scratch.bdash.mobile.analytics.CoreData"
    ///固定文字列：com.f_scratch.bdash.mobile.analytics.first
    public static let kJudgeRestoreDirName:String = "com.f_scratch.bdash.mobile.analytics.first"
    ///固定文字列：bdash.sqlite
    public static let kSqliteFileName:String = "bdash.sqlite"
    ///固定文字列：b_id
    public static let kIdParam:String = "b_id"
    ///RealmからCoreDataへの最大移行件数
    public static let kMigrationMax:UInt = 100
    ///キーチェーン保存用key
    public static let notificationId = "com.f_scratch.bdash.mobile.notificationId"
    ///キーチェーンアカウント名key
    public static let keyChainAccount = "com.f_scratch.bdash.mobile.keyChainAccount"
    ///FCMトークン キーチェーン保存用key（notificationIdとは別領域）
    public static let syncTokenKeyChainGeneric = "com.f_scratch.bdash.mobile.syncTokenId"
    ///FCMトークン キーチェーンアカウント名key
    public static let syncTokenKeyChainAccount = "com.f_scratch.bdash.mobile.syncTokenKeyChainAccount"
    ///Keychainアクセシビリティ移行済みフラグ（一度きりのマイグレーション用）
    public static let kKeychainAccessibilityMigrated = "com.f_scratch.bdash.mobile.keychainAccessibilityMigrated"
    
#if DEBUG
    static func isTesting() -> Bool{
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
#else
    static func isTesting() -> Bool{
        return false
    }
#endif
    
}
