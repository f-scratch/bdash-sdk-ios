import UIKit
import AudioToolbox
import UserNotifications

@objcMembers
public final class BDashNotification: NSObject, Sendable {
    
    enum UNAuthorizationStatus : Int {
        // The user has not yet made a choice regarding whether the application may post user notifications.
        case notDetermined
        // The application is not authorized to post user notifications.
        case denied
        // The application is authorized to post user notifications.
        case authorized
    }
    nonisolated(unsafe) var fcmtkn: String? = nil
    nonisolated(unsafe) var confirmDialog = false
    /// 通信ステータス：PROHIBIT(接続禁止中)
    public static let PROHIBIT = "PROHIBIT"
    /// 通信ステータス：ENABLE(登録成功)
    public static let ENABLE = "ENABLE"
    /// 通信ステータス：DISABLE(登録失敗)
    public static let DISABLE = "DISABLE"
    /// 通信ステータス：ERROR(通信エラー)
    public static let ERROR = "ERROR"
    /// 通信ステータス：通信中
    public static let BUSY = "BUSY"
    
    /// 処理中のトークン処理リクエストがあるか
    nonisolated(unsafe) private var progressTokenRequest = ""
    /// 処理中のトークン処理のコールバッククロージャ
    nonisolated(unsafe) private var progressTokenRequestCompletion : ((_ type:String,_ notificationId:String?,_ response:Data?)->Void)? = nil
    /// 直前の通信結果のステータスコード
    nonisolated(unsafe) var lastServerResponseCode = 0
    /// 直前の通信結果
    public nonisolated(unsafe) var lastServerResponseStatus:String = BDashNotification.PROHIBIT

    /// フォアグラウンド自動同期時BUSYリトライ待機秒数
    fileprivate static let foregroundBusyWaitSeconds:Double = 1
    /// フォアグラウンド自動同期時BUSYリトライ最大回数
    fileprivate static let foregroundBusyWaitCount:Int = 10
    /// フォアグラウンド自動同期時BUSYリトライカウンター
    nonisolated(unsafe) fileprivate static var busyRetryCount:Int = 0 {
        didSet {
            Task { @MainActor in
                BDashLogger.debug("increment busyRetryCount: \(busyRetryCount)")
                if busyRetryCount >= foregroundBusyWaitCount {
                    BDashLogger.debug("end retry because busyRetryCount has reached the limit")
                }
            }
        }
    }
    
    /// App Group Identifier（アプリの Info.plist から取得）
    private let groupIdentifier: String = {
        return Bundle.main.infoDictionary?["APP_BDASH_APP_GROUP_ID"] as? String ?? ""
    }()
    
    nonisolated(unsafe) var bDashNotificationServiceDelegate: BDashNotificationServiceDelegate?
    nonisolated(unsafe) var bDashNotificationModuleDelegate: BDashNotificationModuleDelegate?
    /// 初回のトークン同期か判定
    public nonisolated(unsafe) var isFirstSync = true
    
    /// デフォルトサウンドファイル名
    /// トライトーン
    public static let defaultSoundFileName = "sms-received1.caf"
    /// サウンドの有効/無効
    /// 設定値は永続化される
    public var enableSound:Bool {
        get {
            if let myUserDefaults = UserDefaults(suiteName: "com.sdk.myUserDefaults"){
                return myUserDefaults.bool(forKey: BDashConst.kEnableSoundForPushNotification)
            }
            else {
                return false
            }
        }
        set(newValue) {
            UserDefaults(suiteName: "com.sdk.myUserDefaults")?.set(newValue, forKey: BDashConst.kEnableSoundForPushNotification)
            UserDefaults(suiteName: "com.sdk.myUserDefaults")?.synchronize()
        }
    }
    /// サウンドファイル名
    /// デフォルト sms-received1.caf
    public var soundFileName:String {
        get {
            if let myUserDefaults = UserDefaults(suiteName: "com.sdk.myUserDefaults"),
               let soundFileName = myUserDefaults.string(forKey: BDashConst.kSystemSoundFileNameForPushNotification) {
                return soundFileName
            }
            else {
                return BDashNotification.defaultSoundFileName
            }
        }
        set(newValue) {
            UserDefaults(suiteName: "com.sdk.myUserDefaults")?.set(newValue , forKey: BDashConst.kSystemSoundFileNameForPushNotification)
            UserDefaults(suiteName: "com.sdk.myUserDefaults")?.synchronize()
        }
    }
    /// バイブレーションの有効/無効
    /// 設定値は永続化される
    public var enableVibration:Bool {
        get {
            if let myUserDefaults = UserDefaults(suiteName: "com.sdk.myUserDefaults"){
                return myUserDefaults.bool(forKey: BDashConst.kEnableViblateForPushNotification)
            }
            else {
                return false
            }
        }
        set(newValue) {
            UserDefaults(suiteName: "com.sdk.myUserDefaults")?.set(newValue, forKey: BDashConst.kEnableViblateForPushNotification)
            UserDefaults(suiteName: "com.sdk.myUserDefaults")?.synchronize()
        }
    }

    /// 排他制御用変数
    nonisolated(unsafe) internal var semaphoreTokenRequest = DispatchSemaphore(value: 1)
    
    ///シリアルキュー
    fileprivate let serialDispatchQueueStack = DispatchQueue(label: BDashConst.kPushNotificationSerialQueueStack, attributes: [])
    fileprivate let serialDispatchQueueRun = DispatchQueue(label: BDashConst.kPushNotificationSerialQueueRun, attributes: [])
    
    /// 例外
    enum BDashException: Error {
        // FCM初期化中にトークン処理リクエストを受信した
        case BDashBusyException
    }
    
    // FCMトークン(同期済みトークン)はセキュアなKeychainに保存する。
    // 旧バージョンでUserDefaultsに平文保存された値は、初回読み出し時に一度だけKeychainへ移行する。
    public static var lastSyncTokenId:String? {
        get {
            // Keychainを優先。無ければ旧UserDefaultsから移行する。
            if let token = getSyncTokenFromKeyChain() {
                return token
            }
            let legacyUserDefaults = UserDefaults(suiteName: "com.sdk.myUserDefaults")
            if let legacy = legacyUserDefaults?.string(forKey: BDashConst.kLastSyncTokenId) {
                // 平文の旧データをKeychainへ移行し、UserDefaultsからは削除する
                saveSyncTokenToKeyChain(legacy)
                legacyUserDefaults?.removeObject(forKey: BDashConst.kLastSyncTokenId)
                legacyUserDefaults?.synchronize()
                return legacy
            }
            return nil
        }
        set(newValue) {
            if let newValue = newValue {
                saveSyncTokenToKeyChain(newValue)
            } else {
                deleteSyncTokenFromKeyChain()
            }
            // 平文の旧データが残っていれば併せて削除する
            let legacyUserDefaults = UserDefaults(suiteName: "com.sdk.myUserDefaults")
            if legacyUserDefaults?.object(forKey: BDashConst.kLastSyncTokenId) != nil {
                legacyUserDefaults?.removeObject(forKey: BDashConst.kLastSyncTokenId)
                legacyUserDefaults?.synchronize()
            }
        }
    }

    /// FCMトークンをKeychainに保存する（notificationIdとは別領域）
    private static func saveSyncTokenToKeyChain(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrGeneric as String: BDashConst.syncTokenKeyChainGeneric,
                                     kSecAttrAccount as String: BDashConst.syncTokenKeyChainAccount]
        let matchingStatus = SecItemCopyMatching(query as CFDictionary, nil)
        if matchingStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            if status != errSecSuccess {
                BDashLogger.debug("syncToken keyChain add Error!")
            }
        } else if matchingStatus == errSecSuccess {
            let attributesToUpdate: [String: Any] = [kSecValueData as String: data,
                                                      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if status != errSecSuccess {
                BDashLogger.debug("syncToken keyChain update Error!")
            }
        } else {
            BDashLogger.debug("syncToken keyChain save Error!")
        }
    }

    /// FCMトークンをKeychainから取り出す
    private static func getSyncTokenFromKeyChain() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrGeneric as String: BDashConst.syncTokenKeyChainGeneric,
                                     kSecAttrAccount as String: BDashConst.syncTokenKeyChainAccount,
                                     kSecReturnData as String: kCFBooleanTrue!]
        var data: AnyObject?
        let matchingStatus = withUnsafeMutablePointer(to: &data) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        if matchingStatus == errSecSuccess,
           let getData = data as? Data,
           let getStr = String(data: getData, encoding: .utf8) {
            return getStr
        }
        return nil
    }

    /// FCMトークンをKeychainから削除する
    private static func deleteSyncTokenFromKeyChain() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrGeneric as String: BDashConst.syncTokenKeyChainGeneric,
                                     kSecAttrAccount as String: BDashConst.syncTokenKeyChainAccount]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            BDashLogger.debug("syncToken keyChain delete Error!")
        }
    }

    /// 既存ユーザー向けの一度きりのマイグレーション。
    /// kSecAttrAccessible は SecItemUpdate では変更できないため、既存の Keychain アイテムを
    /// 「削除 → 新しいアクセシビリティ属性で再保存」して旧属性（iCloud同期・バックアップ移行あり）を解消する。
    static func migrateKeychainAccessibilityIfNeeded() {
        let userDefaults = UserDefaults(suiteName: "com.sdk.myUserDefaults")
        if userDefaults?.bool(forKey: BDashConst.kKeychainAccessibilityMigrated) == true {
            return
        }

        // FCMトークン: 既存値を読み出し、削除してから新属性で再保存する
        if let token = getSyncTokenFromKeyChain() {
            deleteSyncTokenFromKeyChain()
            saveSyncTokenToKeyChain(token)
        }

        // 通知ID: 既存値を読み出し、削除してから新属性で再保存する
        let notificationLookupQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                                      kSecAttrGeneric as String: BDashConst.notificationId,
                                                      kSecAttrAccount as String: BDashConst.keyChainAccount]
        var readQuery = notificationLookupQuery
        readQuery[kSecReturnData as String] = kCFBooleanTrue!
        var data: AnyObject?
        let matchingStatus = withUnsafeMutablePointer(to: &data) {
            SecItemCopyMatching(readQuery as CFDictionary, UnsafeMutablePointer($0))
        }
        if matchingStatus == errSecSuccess, let notificationData = data as? Data {
            SecItemDelete(notificationLookupQuery as CFDictionary)
            var addQuery = notificationLookupQuery
            addQuery[kSecValueData as String] = notificationData
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            if status != errSecSuccess {
                BDashLogger.debug("notificationId keyChain migration add Error!")
            }
        }

        userDefaults?.set(true, forKey: BDashConst.kKeychainAccessibilityMigrated)
        userDefaults?.synchronize()
    }
    /**
     コンストラクタ
     */
    public override init() {
        super.init()
        initialize()
    }
    /**
      初期化処理
     */
    private func initialize() {
        // 既存ユーザーの Keychain アイテムを安全なアクセシビリティ属性へ移行する（初回のみ）
        BDashNotification.migrateKeychainAccessibilityIfNeeded()
        UserDefaults(suiteName: "com.sdk.myUserDefaults")?.register(defaults: [BDashConst.kEnableViblateForPushNotification: false])
        UserDefaults(suiteName: "com.sdk.myUserDefaults")?.register(defaults: [BDashConst.kEnableSoundForPushNotification: false])
        UserDefaults(suiteName: "com.sdk.myUserDefaults")?.register(defaults: [BDashConst.kLastServerResponseStatus: BDashNotification.PROHIBIT])
        // デフォルト通知音のファイル指定 (トライトーン)
        UserDefaults(suiteName: "com.sdk.myUserDefaults")?.register(defaults: [BDashConst.kSystemSoundFileNameForPushNotification: BDashNotification.defaultSoundFileName])
        
        // 直前の通信結果をユーザーデフォルトからコピー
        if let status = UserDefaults(suiteName: "com.sdk.myUserDefaults")?.string(forKey: BDashConst.kLastServerResponseStatus){
            self.lastServerResponseStatus = status
        }
//        self.lastServerResponseStatus = UserDefaults(suiteName: "com.sdk.myUserDefaults")!.string(forKey: Const.kLastServerResponseStatus)!
        
        // 初回起動及びリストア後の起動の場合lastServerResponseStatusをPROHIBITに変更する
        if !isJudgeRestoreDir().boolValue {
            // 同期トークンをリセットする
            BDashNotification.lastSyncTokenId = nil
            self.lastServerResponseStatus = BDashNotification.PROHIBIT
            saveLastServerResponseStatus()
            makeJudgeRestoreDir()
        }
        // 送信途中で終わった場合はエラーとして処理
        if self.lastServerResponseStatus == BDashNotification.BUSY {
            self.lastServerResponseStatus = BDashNotification.ERROR
        }
        // 最終ステータスがPROHIBIT以外であれば、初回同期済みと判断
        if self.lastServerResponseStatus != BDashNotification.PROHIBIT {
            self.isFirstSync = false
        }
        // SDKにセットされているFCMトークン値を出力（秘匿情報のためマスク）
        BDashLogger.debug("FCM Token in SDK: \(BDashLogger.mask(self.fcmtkn))")
    }
    /**
     FCMトークンを設定
     */
    public func setFcmToken(fcmToken: String?) {
        self.fcmtkn = fcmToken
        BDashLogger.debug("FCM Token set in SDK: \(BDashLogger.mask(fcmToken))")
    }

    public func getFcmToken() -> String? {
        return self.fcmtkn
    }
    /**
     シングルトンオブジェクトを返す
     - returns:BDashNotificationオブジェクト
     */
    fileprivate class var sharedInstance : BDashNotification {
        struct Static {
            static let instance : BDashNotification = BDashNotification()
        }
        return Static.instance
    }
    /**
     インスタンスを返す
     - returns:BDashNotificationオブジェクト
     */
    public class func getInstance() -> BDashNotification {
        let instance = BDashNotification.sharedInstance
        return instance
    }
    
    /**
     サウンドを鳴らす
     - returns:なし
     */
    func soundSE()-> Void {
        if self.enableSound {
            var soundId:SystemSoundID = 0
            let filePath = "/System/Library/Audio/UISounds/"
            let soundUrl = URL(fileURLWithPath: filePath + self.soundFileName)
            AudioServicesCreateSystemSoundID(soundUrl as CFURL, &soundId)
            AudioServicesPlaySystemSound(soundId)
        }
    }
    /**
     バイブレーションを鳴らす
     - returns:なし
     */
    func vibrate()-> Void {
        if self.enableVibration {
            // 排他制御
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }
  
    // 内部関数
    private func registerNotificationInternal(_ completion: ((@Sendable (_ type:String,_ notificationId:String?,_ response:Data?)->Void)?)) throws {
        // 初回同期時以外で、ステータスがPROHIBITの場合
        if self.isFirstSync == false && lastServerResponseStatus == BDashNotification.PROHIBIT {
            BDashLogger.debug("canceled: registerNotificationInternal() because lastServerResponseStatus is PROHIBIT")
            if let c = completion {
                c(BDashNotification.ERROR, self.fcmtkn ?? "nil", nil)
            }
            return
        }
        // 通信エラー
        if !TrackUtil().isConnectedToNetwork() {
            self.lastServerResponseStatus = BDashNotification.ERROR
            saveLastServerResponseStatus()
            if let c = completion {
                c(BDashNotification.ERROR, self.fcmtkn ?? "nil", nil)
            }
            return
        }
        // FCMトークン値がnilの場合は登録同期しない
        guard let token = self.fcmtkn else {
            BDashLogger.debug("canceled: registerNotificationInternal() because fcm token is nil")
            if let c = completion {
                c(BDashNotification.ERROR, self.fcmtkn ?? "nil", nil)
            }
            return
        }
        // ほぼ同時にリクエストが来てしまった場合のために、排他制御する
        _ = self.semaphoreTokenRequest.wait(timeout: DispatchTime.distantFuture)
        // 処理中のリクエストがあるため例外をスローする
        if self.progressTokenRequest != "" {
            self.semaphoreTokenRequest.signal()
            throw BDashException.BDashBusyException
        }
        // 処理中のリクエスト
        self.progressTokenRequest = BDashNotification.ENABLE
        self.progressTokenRequestCompletion = completion
        self.lastServerResponseStatus = BDashNotification.BUSY
        saveLastServerResponseStatus()
        // 排他制御解除
        self.semaphoreTokenRequest.signal()
        // サーバーでトークン登録処理を実施
        Task {
            await self.registerNotificationStatus(token, completion: completion)
        }
        // 初回同期であれば、初回同期がここで完了するためfalseに更新
        if self.isFirstSync {
            self.isFirstSync = false
        }
    }
    
    // 内部関数
    private func cancelNotificationInternal(_ completion: (@Sendable (_ type:String,_ notificationId:String?,_ response:Data?)->Void)?) throws {
        // 初回同期時以外で、ステータスがPROHIBITの場合
        if self.isFirstSync == false && lastServerResponseStatus == BDashNotification.PROHIBIT {
            BDashLogger.debug("canceled: cancelNotificationInternal() because lastServerResponseStatus is PROHIBIT")
            if let c = completion {
                c(BDashNotification.ERROR, self.fcmtkn ?? "nil", nil)
            }
            return
        }
        // 通信エラー
        if !TrackUtil().isConnectedToNetwork() {
            self.lastServerResponseStatus = BDashNotification.ERROR
            saveLastServerResponseStatus()
            if let c = completion {
                c(BDashNotification.ERROR, "nil", nil)
            }
            return
        }
        // ほぼ同時にリクエストが来てしまった場合のために、排他制御する
        _ = self.semaphoreTokenRequest.wait(timeout: DispatchTime.distantFuture)
        // 処理中のリクエストがあるため例外をスローする
        if self.progressTokenRequest != "" {
            self.semaphoreTokenRequest.signal()
            throw BDashException.BDashBusyException
        }
        // 処理中のリクエスト
        self.progressTokenRequest = BDashNotification.DISABLE
        self.progressTokenRequestCompletion = completion
        self.lastServerResponseStatus = BDashNotification.BUSY
        saveLastServerResponseStatus()
        // 排他制御解除
        self.semaphoreTokenRequest.signal()
        // サーバーでトークン登録処理を実施
        Task {
            await self.registerNotificationStatus(nil, completion: completion)
        }
        // 初回同期であれば、初回同期完了のためfalseに更新
        if self.isFirstSync {
            self.isFirstSync = false
        }
    }
    
    /// OS の通知許可状態を `await` で取得して返す。
    @MainActor @discardableResult func refreshNotificationAuthorized() async -> Bool {
        await self.isRegisterNotification()
    }

    /// OS の通知許可状態を同期的に取得して返す。
    ///
    /// 後方互換の同期 API から使用する。キャッシュ値は使わず、呼び出し時点の
    /// `UNUserNotificationCenter` の設定を completion API 経由で取得する。
    @MainActor func currentNotificationAuthorized() -> Bool {
        self.isRegisterNotificationSynchronously()
    }

    /// 端末の通知ON/OFF設定を取得する
    private func isRegisterNotification() async -> Bool {
        if #available(iOS 10.0, *) {
            var status: Bool = false
            var statusDetail: String = ""
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized:
                status = true
                statusDetail = "enable"
                break
            case .denied:
                status = false
                statusDetail = "disable"
                break
            case .notDetermined:
                status = false
                statusDetail = "notDetermined"
                break
            default:
                status = false
                statusDetail = "nonSupported"
                break
            }
            BDashLogger.debug("isRegisterNotification: \(status) (\(statusDetail)), later iOS 15.0")
            return status
        }else {
            let notificationType =  await UIApplication.shared.currentUserNotificationSettings!.types
            let status = Int(notificationType.rawValue) == 0 ? false : true
            BDashLogger.debug("isRegisterNotification: \(status), earlier iOS 10.0")
            return status
        }
    }

    /// 端末の通知ON/OFF設定を同期的に取得する
    @MainActor private func isRegisterNotificationSynchronously() -> Bool {
        if #available(iOS 10.0, *) {
            final class ResultBox: @unchecked Sendable {
                var status = false
                var statusDetail = "unknown"
            }

            let result = ResultBox()
            let semaphore = DispatchSemaphore(value: 0)
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .authorized:
                    result.status = true
                    result.statusDetail = "enable"
                case .denied:
                    result.status = false
                    result.statusDetail = "disable"
                case .notDetermined:
                    result.status = false
                    result.statusDetail = "notDetermined"
                default:
                    result.status = false
                    result.statusDetail = "nonSupported"
                }
                semaphore.signal()
            }
            semaphore.wait()
            BDashLogger.debug("isRegisterNotification(sync): \(result.status) (\(result.statusDetail)), later iOS 15.0")
            return result.status
        } else {
            let notificationType = UIApplication.shared.currentUserNotificationSettings!.types
            let status = Int(notificationType.rawValue) == 0 ? false : true
            BDashLogger.debug("isRegisterNotification(sync): \(status), earlier iOS 10.0")
            return status
        }
    }
    /**
     プッシュ通知の有効化、無効化登録時のパラメータを取得する
     - parameter: notificationId PUSH通知ID
     - returns: パラメータのNSMutableDictionary
     */
    /* private */func getParamForRegisterNotificationStatus(_ notificationId : String?) async -> NSMutableDictionary {
        // パラメータ構築
        let param = NSMutableDictionary()
        // プッシュ通知ID
        param.setValue(notificationId ?? NSNull(), forKey: "notificationId")
        // UUID
        param.setValue(RootInfoModel().getUUId(), forKey: "uuId")
        // アプリID
        param.setValue(TrackUtil().getPlistData("APP_BDASH_APP_ID"), forKey: "appId")
        // アカウントID
        param.setValue(TrackUtil().getPlistData("APP_BDASH_ACCOUNT_ID"), forKey: "accountId")
        // nil チェック
        // UUIDはnilを許容しない
        if(param["uuid"] == nil) {
            param.removeObject(forKey: "uuid")
        }
        // appIdはnilを許容しない
        if(param["appId"] == nil) {
            param.removeObject(forKey: "appId")
        }
        // accountIdはnilを許容しない
        if(param["accountId"] == nil) {
            param.removeObject(forKey: "accountId")
        }
        // カスタムID
        param.setValue(Tracker.getInstance().customId ?? NSNull(), forKey: "customId")
        //デバイスID
        await param.setValue((UIDevice.current.identifierForVendor?.uuidString)!, forKey: "deviceId")
        // IDFA（ATT 同意がある場合のみセット。未承認時は付与しない）
        if let idfa = Tracker.sharedInstance.attAuthorizedIdfa {
            param.setValue(idfa, forKey: "idfa")
        }
        // デバイス設定言語
        param.setValue(Locale.current.identifier, forKey: "lang")
        //キャリア名取得
        param.setValue("Apple", forKey: "carrier")
        ///アプリバージョン
        param.setValue(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "", forKey: "appVersion")
        //OS名
        param.setValue("iOS", forKey: "os")
        //OSバージョン
        await param.setValue(UIDevice.current.systemVersion, forKey: "osVersion")
        //OSのモデル名
        param.setValue(TrackUtil().currentModelName(), forKey: "model")
        //デバイス解像度
        param.setValue("\(await Int(UIScreen.main.bounds.size.width))x\(await Int(UIScreen.main.bounds.size.height))", forKey: "display")
        //データビューID
        param.setValue(TrackUtil().getPlistData("APP_BDASH_DATA_VIEW"), forKey:"dataViewIds")
        
        return param
    }
    /**
     サーバーURLを取得する
     - returns: サーバーURL
     */
    /* private */func getServerUrl() -> String {
        return BDashConst.kPushNotifyTokenApiUrl
    }
    /**
     共通通信終了処理(マルチスレッドを考慮)
     - parameter lastStatus: 最終サーバーレスポンスステータス
     - returns: なし
     */
    fileprivate func finishNotificationStatus(_ lastStatus:String, paramNId:String?, data:Data?, completion: (@Sendable(_ type:String,_ notificationId:String?,_ response:Data?)->Void)?) -> Void {
        // 通知有効で同期が行われたとき
        if lastStatus == BDashNotification.ENABLE {
            // FCMトークンはlastSyncTokenIdのsetter経由でKeychainに保存される
            BDashNotification.lastSyncTokenId = self.fcmtkn
            BDashLogger.debug( "update last token.\(BDashLogger.mask(BDashNotification.lastSyncTokenId))" )
        }
        //BUSY状態から別のステータスに変更
        self.lastServerResponseStatus = lastStatus
        saveLastServerResponseStatus()
        self.progressTokenRequestCompletion = nil
        
        //通信終了、これ以降registerNotification,cancelNotificationを呼ぶことが可能
        self.progressTokenRequest = ""
        
        if let comp = completion {
            // callback
            comp(lastStatus, paramNId,data)
        }
    }
    
    /// トークン登録のサーバー同期メソッド
    public func registerNotification(completion: (@Sendable (_ type:String,_ notificationId:String?,_ response:Data?)->Void)?) throws {
        do {
            try self.registerNotificationInternal(completion)
        } catch BDashException.BDashBusyException {
            throw BDashException.BDashBusyException
        }
    }

    /// トークン解除のサーバー同期メソッド
    public func cancelNotification(completion: (@Sendable (_ type:String,_ notificationId:String?,_ response:Data?)->Void)?) throws {
        do {
            try self.cancelNotificationInternal(completion)
        } catch BDashException.BDashBusyException {
            throw BDashException.BDashBusyException
        }
    }
    /**
     プッシュ通知の有効化、無効化を行う
     [有効化]notificationIdの値を元に、サーバーでトークン登録処理を実施
     [無効化]notificationIdがnullまたはキーが無い時、サーバーからトークン処理を削除
     - parameter notificationId: PUSH通知ID
     - parameter completion: コールバッククロージャ
     - returns: なし
     */
    private func registerNotificationStatus(_ notificationId : String?,completion: (@Sendable (_ type:String,_ notificationId:String?,_ response:Data?)->Void)?) async {
        // パラメータ構築
        let param = await getParamForRegisterNotificationStatus(notificationId)
        
        // リクエスト構築
        let urlObj:URL = URL(string:getServerUrl())!
        let request:NSMutableURLRequest  = NSMutableURLRequest(url: urlObj)
        request.httpMethod = "POST"
        //http通信のヘッダーを編集する。
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("bdash-sdk / ver=\(Tracker.SDK_VERSION)", forHTTPHeaderField: "User-Agent")
        //リクエストボディの生成
        request.httpBody = TrackUtil().dic2jsonData(param)
        request.timeoutInterval = BDashConst.kRequestPerLimitTime
        //送信タスクの生成
        let task = URLSession.shared
            .dataTask(with: request as URLRequest,completionHandler: {
                data, response,
                error in do {
                    // リクエスト時のnotificationIdを取得
                    var paramNId:String? = nil
                    if let p = param["notificationId"] {
                        paramNId = p as? String
                    }
                    Task { @MainActor in
                        if error == nil, let httpResponse = response as? HTTPURLResponse {
                            // 通信成功
                            let statusCode = httpResponse.statusCode
                            self.lastServerResponseCode = statusCode
                            BDashLogger.debug("B-Dash server response accepted \(statusCode)")
                            
                            if let paramNId = paramNId {
                                BDashLogger.debug("B-Dash server sent notificationId \(paramNId)")
                                self.saveKeyChain(str: paramNId)
                            } else {
                                self.saveKeyChain(str: "")
                            }
                            
                            if statusCode == 200 {
                                // レスポンスOK
                                self.confirmDialog = true
                                var status:String = BDashNotification.ENABLE
                                if paramNId == nil {
                                    // リクエスト時のnotificationIdがnil == 無効化
                                    status = BDashNotification.DISABLE
                                }
                                self.finishNotificationStatus(status, paramNId:paramNId, data:data, completion:completion)
                            } else {
                                // レスポンスエラー
                                BDashLogger.debug("Status Code Error!: ")
                                self.finishNotificationStatus(BDashNotification.ERROR, paramNId:paramNId, data:data, completion:completion)
                            }
                        } else {
                            // 通信失敗
                            BDashLogger.debug("Error!: \(String(describing: error))")
                            
                            // 最新の通信ステータスを記憶しておく
                            self.lastServerResponseCode = 0
                            self.finishNotificationStatus(BDashNotification.ERROR, paramNId:paramNId, data:data, completion:completion)
                        }
                    }
                }
            })
        // 送信タスク実行
        task.resume()
    }
    /**
     キーチェーンにデータを保存する
     - parameter str: 保存する文字列
     - returns: なし
     */
    fileprivate func saveKeyChain(str: String) {
        
        let data = str.data(using: .utf8)

        guard let _data = data else {
            return
        }

        let lookupQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                          kSecAttrGeneric as String: BDashConst.notificationId,
                                          kSecAttrAccount as String: BDashConst.keyChainAccount]

        var itemAddStatus: OSStatus?
        // 保存データが存在するかの確認
        let matchingStatus = SecItemCopyMatching(lookupQuery as CFDictionary, nil)
        if matchingStatus == errSecItemNotFound {
            // 保存する
            var addQuery = lookupQuery
            addQuery[kSecValueData as String] = _data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            itemAddStatus = SecItemAdd(addQuery as CFDictionary, nil)
        } else if matchingStatus == errSecSuccess {
            // 更新する
            let attributesToUpdate: [String: Any] = [kSecValueData as String: _data,
                                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
            itemAddStatus = SecItemUpdate(lookupQuery as CFDictionary, attributesToUpdate as CFDictionary)
        } else {
            BDashLogger.debug("keyChain save Error!)")
        }
        if itemAddStatus != errSecSuccess {
            BDashLogger.debug("keyChain save status Error!")
        }
    }
    /**
     キーチェーンに保存している文字列を取り出す
     - parameter key: 保存したデータのkey
     - returns: キーチェーンに保存している文字列
     */
     fileprivate func getKeyChain(key: String) -> String? {

        let dic: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                  kSecAttrGeneric as String: key,
                                  kSecReturnData as String: kCFBooleanTrue!]

        var data: AnyObject?
        let matchingStatus = withUnsafeMutablePointer(to: &data){
            SecItemCopyMatching(dic as CFDictionary, UnsafeMutablePointer($0))
        }

        if matchingStatus == errSecSuccess {
            if let getData = data as? Data,
                let getStr = String(data: getData, encoding: .utf8) {
                return getStr
            }
            BDashLogger.debug("keyChain get Error! Data is invalid)")
            return nil
        } else {
            BDashLogger.debug("keyChain get Error!)")
            return nil
        }
    }
    /**
     iOS8以降でdidRegisterForRemoteNotificationsWithDeviceTokenを呼ぶために必要
     AppDelegateでdidRegisterUserNotificationSettingsが呼ばれた時に呼ぶ
     - returns:なし
     */
    @MainActor public func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        self.showAlert(userInfo)
        completionHandler(.newData)
    }

    /// フォアグラウンド通知受信時に Host の
    /// `userNotificationCenter(_:willPresent:withCompletionHandler:)` から呼ぶ（推奨経路）。
    ///
    /// OS の通知許可状態（`authorizationStatus`）を `await` で確認し、
    /// **許可されている場合のみ** SDK 独自のリッチアラートを表示する。OS設定で通知が
    /// OFF（`.denied` / `.notDetermined`）のときはアラートを表示せず、OSバナーも出さない
    /// （`[]` を返す）。リッチPushの画像は、NSE が `_sharedMediaPath` を書き込めない
    /// 場合でも payload の画像URLから SDK が自前取得して表示する。
    ///
    /// 使い方:
    /// ```swift
    /// func userNotificationCenter(_ center: UNUserNotificationCenter,
    ///                             willPresent notification: UNNotification,
    ///                             withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    ///     Task { @MainActor in
    ///         let options = await BDashNotification.getInstance().willPresentNotification(notification)
    ///         completionHandler(options)
    ///     }
    /// }
    /// ```
    @MainActor public func willPresentNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions {
        await willPresentNotification(userInfo: notification.request.content.userInfo)
    }

    /// `userInfo` を直接渡す async オーバーロード（独自経路・ブリッジ向け）。
    @MainActor public func willPresentNotification(userInfo: [AnyHashable: Any]) async -> UNNotificationPresentationOptions {
        let contents = createAlertContents(from: userInfo)
        // バッジ更新等の silent payload（alert が無いもの）は表示しない
        let aps = userInfo["aps"] as? [AnyHashable: Any]
        guard aps?["alert"] != nil || userInfo["notification"] != nil else {
            return []
        }
        // OS設定で通知が OFF のときは SDK 独自アラートを表示しない。
        // （`isRegisterNotification()` は authorizationStatus を都度取得して判定する）
        guard await self.isRegisterNotification() else {
            BDashLogger.debug("willPresentNotification: skip showAlert because OS notification is disabled")
            return []
        }
        if contents.playSound {
            self.vibrate()
            self.soundSE()
        }
        self.showAlert(userInfo)
        // SDK 独自アラートを表示するため OS バナーは抑止。
        return []
    }

    /// フォアグラウンド通知受信時の同期版（後方互換）。
    ///
    /// `notificationSettings()` は async のため、後方互換の同期版では completion API を
    /// 同期的に待ち、呼び出し時点の許可状態を確認する。
    @MainActor public func willPresentNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        willPresentNotification(userInfo: notification.request.content.userInfo)
    }

    /// `userInfo` を直接渡す同期オーバーロード（後方互換）。
    @MainActor public func willPresentNotification(userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        // バッジ更新等の silent payload（alert が無いもの）は表示しない
        let aps = userInfo["aps"] as? [AnyHashable: Any]
        guard aps?["alert"] != nil || userInfo["notification"] != nil else {
            return []
        }
        // OS設定で通知が OFF のときは SDK 独自アラートを表示しない
        guard self.currentNotificationAuthorized() else {
            BDashLogger.debug("willPresentNotification(sync): skip showAlert because OS notification status is disabled")
            return []
        }
        self.showAlert(userInfo)
        // SDK 独自アラートを表示するため OS バナーは抑止。音・バッジは OS に任せる。
        return [.sound, .badge]
    }
    /**
     アラート表示
     - parameter title: アラートタイトル
     - parameter body: アラート本文
     - parameter image: アラート画像
     - parameter playSound: trueなら音とバイブレートを鳴らす
     - returns:なし
     */
    @MainActor func showAlert(_ userInfo: [AnyHashable: Any]) {
        BDashLogger.debug("showAlert")
        let contents = createAlertContents(from: userInfo)
        DispatchQueue.main.async {
            // BDashAlert 系は後から画像を差し込めるよう参照を保持する
            var bdashAlert: BDashAlertViewController?
            let alert: UIViewController = {
                if #available(iOS 9.0, *) {
                    let alertType = contents.alertType
                    if alertType == .BDashAlert {
                        let vc = BDashAlertViewController(from: contents)
                        bdashAlert = vc
                        return vc
                    } else if alertType == .BDashDoubleButtonAlert {
                        let vc = BDashDoubleButtonAlertViewController(from: contents)
                        bdashAlert = vc
                        return vc
                    }
                }
                let title = contents.title
                let body = contents.body
                let alert = UIAlertController(title:title, message: body, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "閉じる", style: .default, handler: nil))
                return alert
            }()
            var baseView:UIViewController = (UIApplication.shared.windows.first { $0.isKeyWindow }!.rootViewController)!
            while(baseView.presentedViewController != nil &&
                !(baseView.presentedViewController?.isBeingDismissed)!) {
                    baseView = baseView.presentedViewController!
            }
            baseView.present(alert, animated: true, completion: nil)

            if contents.playSound {
                self.vibrate()
                self.soundSE()
            }

            // _sharedMediaPath で画像が取れず、payload に画像URLがある場合（フォアグラウンド・NSE非依存）は
            // 非同期取得して表示中のアラートへ後差し込みする。テキストは即時表示される。
            if contents.image == nil,
               let urlString = contents.fallbackImageURLString,
               let bdashAlert = bdashAlert {
                self.fetchFallbackImage(urlString: urlString) { image in
                    guard let image = image else { return }
                    bdashAlert.applyLateImage(image)
                }
            }
        }
    }
    
    /// 通知受信ペイロードからアラート表示コンテンツ(設定)を作成する
    ///
    /// SwiftUI ラッパー（`BDashPushAlertController`）からペイロード→Contents 変換を委譲するために公開している。
    @MainActor public func createAlertContents(from userInfo: [AnyHashable: Any]) -> BDashAlertViewContents {
        let contents = BDashAlertViewContents()
        let fcmApi = userInfo["fcm_api"] as? String

        
        if let aps = userInfo["aps"] as? NSDictionary,
           let alert = aps["alert"] as? NSDictionary {
            contents.title = alert["title"] as? String
            if let body = alert["body"] as? String {
                contents.body = body
                if let rawParam = userInfo["param"] as? String {
                    let param = rawParam.removingPercentEncoding ?? rawParam
                    contents.body = !(param.isEmpty) ? body + " param : " + param : body
                    contents.param = param
                }
            }
        } else if let notification = userInfo["notification"] as? NSDictionary {
            contents.title = notification["title"] as? String
            if let body = notification["body"] as? String {
                contents.body = body
                if let rawParam = userInfo["param"] as? String {
                    let param = rawParam.removingPercentEncoding ?? rawParam
                    contents.body = !(param.isEmpty) ? body + " param : " + param : body
                    contents.param = param
                }
            }
        }
        if fcmApi == "v1"{
            if let customPayload = userInfo["custom_payload"] as? String {
                if let dataPayload = Data(base64Encoded: customPayload, options: Data.Base64DecodingOptions.ignoreUnknownCharacters){
                    let decodedPayload = String(data: dataPayload, encoding: .utf8)
                    let decodedPayloadData = decodedPayload?.data(using: .utf8)
                    do {
                        if let data = decodedPayloadData{
                            if let jsonArray = try JSONSerialization.jsonObject(with: data, options : []) as? [AnyHashable:Any]
                            {
                                // 通知ペイロード本文は秘匿情報を含みうるため、構造（キー名・ボタン数）のみ出力する
                                let buttonCount = (jsonArray["buttons"] as? [Any])?.count ?? 0
                                BDashLogger.debug("custom_payload parsed: keys=\(jsonArray.keys) buttons=\(buttonCount)")
                                if let buttonList = jsonArray["buttons"] as? Array<Dictionary<String,Any>>{
                                    for buttonItem in buttonList {
                                        var param: String?
                                        if let rawParam = buttonItem["notification_param"] as? String {
                                            param = rawParam.removingPercentEncoding ?? rawParam
                                        }
                                        let buttonItemContents = BDashAlertButtonContents(
                                            number: buttonItem["number"] as? Int,
                                            notificationParam: param,
                                            label: buttonItem["label"] as? String)
                                        contents.addAlertButton(of: buttonItemContents)
                                    }
                                    let buttonCounts = contents.alertButtons.count
                                    let allCaseCount = BDashAlertViewContents.BDashAlertType.allCase.count
                                    contents.alertType = buttonCounts >= allCaseCount ? .BDashDoubleButtonAlert : .BDashAlert
                                    contents.validateButtonLayout()
                                }
                            } else {
                                BDashLogger.debug("bad json")
                            }
                        }
                    } catch let error as NSError {
                        BDashLogger.debug("\(error)")
                    }
                }
            }
        }
        else if fcmApi == "legacy"{
            if let buttons = userInfo["buttons"] as? String?, let str = buttons,
               let data = str.data(using: String.Encoding.utf8) {
                // ボタン定義 JSON は秘匿情報を含みうるため、文字数のみ出力する
                BDashLogger.debug("buttons parsed: \(str.count) chars")
                do {
                    if let buttonList = try JSONSerialization.jsonObject(with: data) as? [Dictionary<String, Any>] {
                        for buttonItem in buttonList {
                            var param: String?
                            if let rawParam = buttonItem["notification_param"] as? String {
                                param = rawParam.removingPercentEncoding ?? rawParam
                            }
                            let buttonItemContents = BDashAlertButtonContents(
                                                        number: buttonItem["number"] as? Int,
                                                        notificationParam: param,
                                                        label: buttonItem["label"] as? String)
                            contents.addAlertButton(of: buttonItemContents)
                        }
                        let buttonCounts = contents.alertButtons.count
                        let allCaseCount = BDashAlertViewContents.BDashAlertType.allCase.count
                        contents.alertType = buttonCounts >= allCaseCount ? .BDashDoubleButtonAlert : .BDashAlert
                        contents.validateButtonLayout()
                    } else {
                        BDashLogger.debug("failure: buttonList is nil")
                    }
                } catch {
                    BDashLogger.debug("failure: couldn't get the contents of buttons payload")
                }
            }
        } else if let rawParam = userInfo["notification_param"] as? String {
            contents.notificationParam = rawParam.removingPercentEncoding ?? rawParam
        }
        if let isWithOverray = userInfo["with_overray"] as? String {
            if isWithOverray == "true" || isWithOverray == "TRUE" {
                contents.isWithOverray = true
            } else if isWithOverray == "false" || isWithOverray == "FALSE" {
                contents.isWithOverray = false
            }
        }
        let isActive: Bool = UIApplication.shared.applicationState == .active
        contents.playSound = isActive ? true : false
        contents.showImage = true
        if #available(iOS 10.0, *) {
            if let mediaUrlString = userInfo["_sharedMediaPath"] as? String,
               let mediaUrl = URL(string: mediaUrlString),
               mediaUrl.scheme == "file",
               isInsideAppGroupContainer(mediaUrl) {
                do {
                    let fileData = try Data(contentsOf: mediaUrl)
                    if let image = UIImage(data: fileData) {
                        contents.image = image
                    } else {
                        BDashLogger.debug("failure: couldn't get the attached image")
                    }
                } catch {
                    BDashLogger.debug("failure: shared container error \(error)")
                }
            } else {
                BDashLogger.debug("failure: couldn't decode the attached image media path")
            }
            // _sharedMediaPath から画像が取れなかった場合（フォアグラウンド・NSE非依存）に備え、
            // payload の画像URLを保持しておく（実際の取得は表示時に非同期で行う）。
            // NSE と同じキー: fcm v1 → fcm_options.image / legacy → mediaUrl
            if contents.image == nil {
                if fcmApi == "v1" {
                    let fcmOptions = userInfo["fcm_options"] as? [AnyHashable: Any]
                    contents.fallbackImageURLString = fcmOptions?["image"] as? String
                } else {
                    contents.fallbackImageURLString = userInfo["mediaUrl"] as? String
                }
            }
        } else {
            BDashLogger.debug("caution: media notifications are not available")
            BDashLogger.debug("because ios version is earlier 10.0")
        }
        return contents
    }

    /// 指定 URL が App Group 共有コンテナ配下のファイルを指すかを判定する。
    /// ペイロードの `_sharedMediaPath` で SQLite 等の任意ファイルを指定されても読み込まないようにする。
    private func isInsideAppGroupContainer(_ url: URL) -> Bool {
        guard !groupIdentifier.isEmpty,
              let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
            return false
        }
        let containerPath = containerUrl.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        return targetPath == containerPath || targetPath.hasPrefix(containerPath + "/")
    }

    /// payload の画像URL文字列から画像を非同期取得する（フォアグラウンド・NSE非依存フォールバック）。
    /// - Parameters:
    ///   - urlString: `fcm_options.image`(v1) または `mediaUrl`(legacy) の URL 文字列
    ///   - completion: メインアクター上で呼ばれる。取得失敗時は nil。
    nonisolated func fetchFallbackImage(urlString: String, completion: @escaping @MainActor @Sendable (UIImage?) -> Void) {
        guard let url = URL(string: urlString), url.scheme?.lowercased() == "https" else {
            BDashLogger.debug("failure: fallback image URL must be https")
            Task { @MainActor in completion(nil) }
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            // NSE の downloadMedia と同等に UIImage(data:) で検証する
            let image: UIImage? = {
                guard let data = data, let image = UIImage(data: data) else { return nil }
                return image
            }()
            if image == nil {
                BDashLogger.debug("failure: couldn't fetch fallback image, error: \(String(describing: error))")
            }
            Task { @MainActor in completion(image) }
        }.resume()
    }
    /**
     共通領域から画像を削除する
     - returns:なし
     */
    public func removeSharedImage() {
        // 一覧取得
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupIdentifier) else {
            return
        }
        var list = self.getFileInfoListInDir(containerUrl.path)
        list = list.filter { !($0.hasSuffix(".plist") || $0.hasSuffix("Library")) }
        // 現在より1時間前の時間
        let dateFormat = "yyyyMMddHHmmssSSS"
        let targetDate = Date(timeIntervalSinceNow: -60 * 60)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "GMT")
        df.dateFormat = dateFormat
        // ファイルのtimeStampが1時間以上前の画像名を検出
        list = list.filter{
            guard let timeStamp = df.date(from: String($0.prefix(dateFormat.count))) else {
                return false
            }
            return timeStamp < targetDate
        }
        // 削除
        list.forEach {
            do {
                try FileManager.default.removeItem(atPath: containerUrl.path + "/" + $0)
                BDashLogger.debug("removeSharedImage has successfully deleted notification images")
            } catch {
                BDashLogger.debug("removeSharedImage faled in deleted notification images, error: \(error)")
            }
        }
    }
    
    /**
     ディレクトリ内のディレクトリ・ファイル名リストを取得します。
     - Parameter dirName: ディレクトリ名
     - Returns: ディレクトリ・ファイル名リスト
     */
    fileprivate func getFileInfoListInDir(_ dirName: String) -> [String] {
        let fileManager = FileManager.default
        var files: [String] = []
        do {
            files = try fileManager.contentsOfDirectory(atPath: dirName)
        } catch {
            return files
        }
        return files
    }
    
    /**
     サーバーにPUSH通知の許可状態を通知する
     - returns:なし
     */
    public func applicationWillEnterForegroundSync() async {
        BDashLogger.debug("start applicationWillEnterForeground()")
        // 通知許可ダイアログ未表示（.notDetermined）の場合は同期しない
        let authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if authorizationStatus == .notDetermined {
            BDashLogger.debug("canceled: applicationWillEnterForeground() because authorization is not determined")
            return
        }
        // サーバーの最終ステータス
        let lastResponse = self.lastServerResponseStatus
        BDashNotification.busyRetryCount = 0
        var bRetryAutoSync:Bool = false
        repeat {
            bRetryAutoSync = false
            do {
                BDashLogger.debug("last status: \(lastResponse)")
                // 端末の通知ON/OFF設定のフラグ
                let notificationSettingStatus: Bool = await self.isRegisterNotification()
                if notificationSettingStatus {
                    // 通知設定がONのとき
                    // トークン登録同期
                    BDashLogger.debug("need sync (also BUSY)")
                    var progressTokenRequestCompletion: (@Sendable (_ type:String,_ notificationId:String?,_ response:Data?) -> Void)? = nil
                    
                    progressTokenRequestCompletion = {(type, notificationId, response) in
                        Task { @MainActor in
                            BDashLogger.debug("[register] type: \(lastResponse) -> \(type)")
                            BDashLogger.debug("[register] notificationId: \(notificationId ?? "nil")")
                            if let res = response {
                                BDashLogger.debug("[register] response: \(BDashLogger.mask(data: res))")
                            }
                            BDashLogger.debug("end applicationWillEnterForeground()")
                        }
                        
                    }
                    try self.registerNotificationInternal(progressTokenRequestCompletion)
                } else {
                    // 通知設定がOFFのとき
                    if lastResponse == BDashNotification.DISABLE {
                        BDashLogger.debug("no need sync")
                    } else {
                        // トークン解除同期
                        BDashLogger.debug("need sync (also BUSY)")
                        var cancelTokenRequestCompletion : (@Sendable (_ type:String,_ notificationId:String?,_ response:Data?) -> Void)? = nil
                        cancelTokenRequestCompletion = {(type, notificationId, response) in
                            Task { @MainActor in
                                BDashLogger.debug("[cancel] type: \(lastResponse)  -> \(type)")
                                BDashLogger.debug("[cancel] notificationId: \(notificationId ?? "nil")")
                                if let res = response {
                                    BDashLogger.debug("[cancel] response: \(BDashLogger.mask(data: res))")
                                }
                                BDashLogger.debug("end applicationWillEnterForeground()")
                            }
                        }
                        try self.cancelNotificationInternal(cancelTokenRequestCompletion)
                    }
                }
            } catch BDashException.BDashBusyException {
                BDashLogger.debug("caught busy exception")
                BDashNotification.busyRetryCount += 1
                if BDashNotification.busyRetryCount < BDashNotification.foregroundBusyWaitCount {
                    // 待機してリトライ
                    bRetryAutoSync = true
                    BDashLogger.debug("retry after \(BDashNotification.foregroundBusyWaitSeconds) seconds")
                    try? await Task.sleep(nanoseconds: UInt64(BDashNotification.foregroundBusyWaitSeconds * 1_000_000_000))
                }
            } catch {
                BDashLogger.debug("caught exception")
            }
            // リトライが発生しているとき再度同期を試みる
        } while bRetryAutoSync
    }
    /**
     クリティカルセクションでブロックを実行する
     - param: lock lockオブジェクト
     - param: proc ブロック
     */
    fileprivate func synchronized(_ lock: AnyObject?, proc: () -> ()) {
        guard let lock = lock else { return }
        objc_sync_enter(lock)
        proc()
        objc_sync_exit(lock)
    }
    
    /**
     直前の通信結果をユーザーデフォルトに保存する
     */
    fileprivate func saveLastServerResponseStatus(){
        UserDefaults(suiteName: "com.sdk.myUserDefaults")?.set(self.lastServerResponseStatus , forKey: BDashConst.kLastServerResponseStatus)
        UserDefaults(suiteName: "com.sdk.myUserDefaults")?.synchronize()
    }
    /**
     リストア判定用のディレクトリの有無を調べる
     */
    fileprivate func isJudgeRestoreDir() -> ObjCBool {
        let fileManager = FileManager.default
        var isDir : ObjCBool = false
        fileManager.fileExists(atPath: self.judgeRestoreDirPath, isDirectory: &isDir)
        return isDir
    }
    /**
     リストア判定用のディレクトリを作成する
     */
    fileprivate func makeJudgeRestoreDir(){
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(atPath: self.judgeRestoreDirPath, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            BDashLogger.debug("\(error)")
        }
        _ = addSkipBackupAttributeToItemAtURL(self.judgeRestoreDirPath)
    }
    
    // リストア判定用のディレクトリのパス
    nonisolated(unsafe) var judgeRestoreDirPath: String = {
        let libraryPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0] as String
        //iCloudバックアップ対象かつユーザーからは見えないパスを設定
        let path = libraryPath + "/" + BDashConst.kJudgeRestoreDirName
        return path
    }()
    
    /**
     pathのディレクトリにNSURLIsExcludedFromBackupKey属性を付与
     */
    func addSkipBackupAttributeToItemAtURL(_ filePath:String) -> Bool {
        let target:URL = URL(fileURLWithPath: filePath)
        
        if !FileManager.default.fileExists(atPath: filePath) {
            BDashLogger.debug("File \(filePath) does not exist")
            return false
        }
        var success: Bool
        do {
            try (target as NSURL).setResourceValue(true, forKey:URLResourceKey.isExcludedFromBackupKey)
            success = true
        } catch let error as NSError {
            success = false
            BDashLogger.debug("Error excluding \(target.lastPathComponent) from backup \(error)")
        }
        return success
    }
    
    public func getLastServerResponseStatus() -> String {
        return self.lastServerResponseStatus
    }
}

@objc protocol BDashNotificationServiceDelegate {
    func sendStatus(type: String)
    func incrementCount(result: Bool)
    func setCountIfBackground()
}

@objc protocol BDashNotificationModuleDelegate {
    func checkRetryRegisterCancel()
}
