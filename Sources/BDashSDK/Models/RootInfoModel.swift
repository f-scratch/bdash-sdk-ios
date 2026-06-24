import Foundation
import UIKit

public final class RootInfoModel: NSObject, Sendable {
    ///デバイスID
    nonisolated(unsafe) var deviceId=""
    ///UUID
    nonisolated(unsafe) var uuId=""
    ///アプリID
    nonisolated(unsafe) var appId=""
    ///カスタマーID
    nonisolated(unsafe) var customId:String!
    /// アカウントID
    nonisolated(unsafe) var accountId=""
    /// トークンID
    nonisolated(unsafe) var tokenId:String!
    /// デバイス設定言語
    nonisolated(unsafe) var lang=""
    /// ログインユーザーID
    nonisolated(unsafe) var loginUserId=""
    /// idfa
    nonisolated(unsafe) var idfa:String!
    
    ///キャリア名
    nonisolated(unsafe) var carrier=""
    ///アプリバージョン
    nonisolated(unsafe) var appVersion=""
    ///デバイスOS名
    nonisolated(unsafe) var os=""
    ///デバイスOSバージョン
    nonisolated(unsafe) var osVersion=""
    ///デバイスブランド/モデル名
    nonisolated(unsafe) var model=""
    ///デバイス解像度
    nonisolated(unsafe) var display=""
    ///データビュー
    nonisolated(unsafe) var dataViewIds=""
    
    /// 排他制御用変数
    nonisolated(unsafe) internal static var semaphoreGetUUId = DispatchSemaphore(value: 1)
    /**
     model情報からjsonの格納階層（マップ）にセットする。
     - returns: jsonの格納階層
     */
    func model2Dictionary()-> NSMutableDictionary {
        let dictionary = NSMutableDictionary()
        dictionary.setValue(self.deviceId, forKey: "deviceId")
        dictionary.setValue(self.uuId, forKey: "uuId")
        dictionary.setValue(self.appId, forKey: "appId")
        dictionary.setValue(self.accountId, forKey: "accountId")
        if self.tokenId != nil {
            dictionary.setValue(self.tokenId, forKey: "tokenId")
        }
        
        dictionary.setValue(self.lang, forKey: "lang")
        dictionary.setValue(self.carrier, forKey: "carrier")
        dictionary.setValue(self.appVersion, forKey: "appVersion")
        dictionary.setValue(self.os, forKey: "os")
        dictionary.setValue(self.osVersion, forKey: "osVersion")
        dictionary.setValue(self.model, forKey: "model")
        dictionary.setValue(self.display, forKey: "display")
        dictionary.setValue(self.dataViewIds, forKey: "dataViewIds")
        if self.customId != nil {
            dictionary.setValue(self.customId, forKey: "customId")
        }
        if self.idfa != nil {
            dictionary.setValue(self.idfa, forKey: "idfa")
        }
        dictionary.setValue(NSMutableArray(), forKey: "trackings")
        return dictionary
    }
    /**
     uuid を取得する
     - returns: 端末の UUID を返す
     */
    @discardableResult
    public func getUUId() -> String {
        // 排他制御開始
        _ = RootInfoModel.semaphoreGetUUId.wait(timeout: DispatchTime.distantFuture)
        
        var uuid = TrackUtil().getUserDefaults(BDashConst.kBaseUserDefaultsKey + "uuid")
        if uuid.isEmpty {
            TrackUtil().setUserDefaults(BDashConst.kBaseUserDefaultsKey + "uuid", value: UUID().uuidString)
            uuid = TrackUtil().getUserDefaults(BDashConst.kBaseUserDefaultsKey + "uuid")
        }
        // 排他制御終了
        RootInfoModel.semaphoreGetUUId.signal()
        return uuid
    }
    /**
     model情報からjsonの格納階層（マップ）にセットする。
     - parameter customId: カスタマーID
     - returns: jsonの格納階層
     */
    public func buildRootInfo(_ customId:String?) async -> NSMutableDictionary {
        let roots=RootInfoModel()
        roots.customId = customId
        //デバイスID
        roots.deviceId = await (UIDevice.current.identifierForVendor?.uuidString)!
        //UUID
        roots.uuId = getUUId()
        //IDFA（ATT 同意がある場合のみセット。未承認時は nil となり送信対象から除外される）
        roots.idfa = Tracker.sharedInstance.attAuthorizedIdfa
        let APP_BDASH_APP_ID = TrackUtil().getPlistData("APP_BDASH_APP_ID")
        let APP_BDASH_ACCOUNT_ID = TrackUtil().getPlistData("APP_BDASH_ACCOUNT_ID")

        /// デバイス設定言語
        roots.lang = Locale.current.identifier
        //キャリア名取得
        roots.carrier = "Apple"
        ///アプリバージョン
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        roots.appVersion = version
        //OS名
        roots.os = "iOS"
        //OSバージョン
        roots.osVersion = await UIDevice.current.systemVersion
        //OSのモデル名
        roots.model = TrackUtil().currentModelName()
        //デバイス解像度
        let boundSize = await UIScreen.main.bounds.size
        let boundSizeStr: NSString = "\(Int(boundSize.width))x\(Int(boundSize.height))" as NSString
        roots.display = boundSizeStr as String
        ///アプリID
        roots.appId = APP_BDASH_APP_ID
        ///アカウントID
        roots.accountId = APP_BDASH_ACCOUNT_ID
        //データビュー
        roots.dataViewIds = TrackUtil().getPlistData("APP_BDASH_DATA_VIEW")
        return roots.model2Dictionary()
    }
}
