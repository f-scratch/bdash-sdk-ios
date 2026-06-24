import Foundation
import SystemConfiguration

/// トラッキングデータ操作ユーティリティ
@objcMembers
public class TrackUtil: NSObject {
    /**
      文字列（json)をDictionaryオブジェクトに変換
      - parameter target: 変換文字列
      - returns: NSMutableDictionaryオブジェクト
      */
     public func json2Dictionary(_ target:String)-> NSMutableDictionary{
         guard let data = target.data(using: String.Encoding.utf8) else {
             return NSMutableDictionary()
         }
         do {
             if let dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? NSMutableDictionary {
                 return dict
             }
         } catch let error {
             BDashLogger.debug("\(error)")

         }
         return NSMutableDictionary()
     }
     /**
      mapオブジェクトをjson文字列に変換する。
      - parameter dict: 変換前mapオブジェクト
      - returns: json文字列
      */
     public func dic2json(_ dict:NSDictionary)-> String{
         do {
             // Dict -> JSON
             let jsonData = try JSONSerialization.data(withJSONObject: dict, options: []) //(*)options??
             
             let json = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
             return json
         } catch let error {
             BDashLogger.debug("\(error)")
         }
         return ""
     }
     /**
      間隔時間をログに出力
      - parameter startDate: 開始日付
      - parameter transactionId: 計測対象トランザクションID
      - returns: なし
      */
     public func timeInterval(_ startDate:Date,transactionId:String){
         let time = Date().timeIntervalSince(startDate) // 現在時刻と開始時刻の差
         let hh = Int(time / 3600)
         let mm = Int((time - Double(hh * 3600)) / 60)
         let ss = Int(time - Double(hh * 3600 + mm * 60))
         _ = String(format: "\(transactionId)# %02d:%02d:%02d", hh, mm, ss)
     }
     
     /**
      dictionaryオブジェクトをjsonデータ（mapオブジェクト）に変換
      - ＊レスポンスをデバッグするために使用
      - parameter data:NSDataオブジェクト
      - returns: なし
      */
     public func data2Dictionary(_ data:Data)-> NSDictionary?{
         do {
             guard let json = try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions.allowFragments ) as? NSDictionary else {
                 return nil
             }
             return json
         } catch {
             BDashLogger.debug("\(error)")
         }
         return nil
     }
     /**
      ディクショナリオブジェクトをjson（NSData）に変換
      - parameter dict:NSMutableDictionaryオブジェクト
      - returns: json（NSData）
      */
     public func dic2jsonData(_ dict:NSMutableDictionary)-> Data?{
         do {
             // Dict -> JSON
             let jsonData = try JSONSerialization.data(withJSONObject: dict, options: []) //(*)options??
             
             return jsonData
         } catch let error {
             BDashLogger.debug("\(error)")
             
         }
         return nil
     }
     /**
      アプリの Info.plist から設定値を取得
      - parameter key: Info.plist 属性のキー (例: APP_BDASH_APP_ID)
      - returns: 設定値（未設定時は空文字列）
      */
     public func getPlistData(_ key:String)-> String{
         return Bundle.main.infoDictionary?[key] as? String ?? ""
     }
     /**
      トランザクションID生成from_toの形式で生成する。
      - 処理概要：TrackingModel情報のどこからどこまでを処理対象とするか管理するために、トランザクションID生成する。TrackingModelのidを元に生成する。書式：開始id + '_' + 終了id
      - parameter selectList:TrackingModel情報リスト
      - returns: トランザクションID
      */
     public func generateTrasactionId(_ selectList:NSMutableArray)-> String{
         if selectList.count > 1 {
             let beginModel=selectList.object(at: 0) as! BDashTrackingData
             let endModel=selectList.object(at: selectList.count-1)as! BDashTrackingData
             return (String(describing: beginModel.b_id) + "_" + String(describing: endModel.b_id))
         } else if selectList.count == 1 {
             let beginModel=selectList.object(at: 0) as! BDashTrackingData
             let endModel=selectList.object(at: 0)as! BDashTrackingData
             return (String(describing: beginModel.b_id) + "_" + String(describing: endModel.b_id))
         }
         return ""
     }
     /**
      ユーザデフォルトを取得する。
      - parameter key:ユーザデフォルトキー
      - returns: ユーザデフォルトバリュー
      */
     public func getUserDefaults(_ key:String)-> String{
         // 「ud」というインスタンスをつくる。
         let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
         // キーがidの値をとります。
         if let value = ud?.object(forKey: key) as? String {
             return value
         }else {
             return ""
         }
     }
     /**
      ユーザデフォルトをセットする。
      - parameter key:ユーザデフォルトキー
      - parameter value: ユーザデフォルトバリュー
      - returns: なし
      */
     public func setUserDefaults(_ key:String,value:String){
         // 「ud」というインスタンスをつくる。
         let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
         // キーがidの値をとります。
         ud?.set(value, forKey: key)
         ud?.synchronize()
     }
     /**
      端末モデル名を取得する。
      - returns: モデル名
      */
     public func currentModelName()-> String{
         var size: Int = 0
         sysctlbyname("hw.machine", nil, &size, nil, 0)
         var machine = [CChar](repeating: 0, count: Int(size))
         sysctlbyname("hw.machine", &machine, &size, nil, 0)
         return String(cString: machine)
     }
     /**
      リスト（トランザクション情報）から一番大きいTrackingModelのIDを取得
      - parameter searchList:検索リスト
      - returns: 最大のID
      
      */
     public func getMaxId(_ searchList:NSMutableArray)-> Int64{
         var maxId: Int64 = 0
         for element in searchList{
             guard let transactionInfo = element as? TransactionInfo else { continue }
             let transact = transactionInfo.id
             if let tanIds = transact?.components(separatedBy: "_"),
                tanIds.count > 1,
                let id = Int64(tanIds[1]),
                maxId < id {
                 maxId = id
             }
         }
         return maxId
     }
     /**
      TrackingModelのIDを生成する。
      - returns: 生成ID
      */
     public func generateTrackingId() -> Int64 {
         let now = Date()
         
         let formatter = DateFormatter()
         formatter.dateFormat = "yyyyMMddHHmmssSSS"
         formatter.locale = Locale(identifier: "en_US_POSIX")
         let str:String = formatter.string(from: now)
         let result:Int64 = Int64(str)!
         return result*10
     }
     /**
      日付取得
      - returns: eventDate(イベント日付)
      */
     public func generateEventDate() -> String {
         let now = Date()
         let formatter = DateFormatter()
         formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
         formatter.locale = Locale(identifier: "en_US_POSIX")
         let str:String = formatter.string(from: now)
         return str
     }
     /**
      対象リストから対象のトランザクションIDを削除
      - parameter searchList:検索リスト
      - parameter target: 検索対象
      - returns: なし
      */
     public func removeTargetKye(_ searchList:NSMutableArray,target:String){
         let removes:NSMutableArray = NSMutableArray()
         objc_sync_enter(searchList)
         for element in searchList{
             let info=element as! TransactionInfo
             if info.id == target {
                 removes.add(element)
             }
         }
         for remove in removes{
             searchList.remove(remove)
         }
         objc_sync_exit(searchList)
     }
     /**
      遅延してるリクエストを削除する。
      - parameter searchList:検索リスト
      - returns: なし
      */
     public func removeDelayRequest(_ searchList:NSMutableArray){
         let current = generateTrackingId()
         let mutableArray=NSMutableArray()
         for element in searchList{
             let info=element as! TransactionInfo
             if (current - info.date) > 600000 {
                 mutableArray.add(info)
             }
         }
         for removeElement in mutableArray{
             searchList.remove(removeElement)
         }
     }
     /**
      クエリパラメータをDictionaryに編集する。
      - parameter searchList:検索リスト
      - returns: Dictionaryオブジェクト（属性名、値）
      */
     public func parseGetArgments(_ urlStr:String) -> Dictionary<String, String>{
         let components = urlStr.components(separatedBy: "?")
         var dict : Dictionary<String, String> = Dictionary<String, String>()
         guard components.count > 1 else { return dict }
         let queryString = components[1]
         for param in queryString.components(separatedBy: "&"){
             let keyValue = param.components(separatedBy: "=")
             guard keyValue.count > 1 else { continue }
             dict[keyValue[0]] = keyValue[1]
         }
         return dict
     }
     /**
      入力されたuserMap/eventMap を整形して空のキーを省いたオブジェクトに変換する。
      - parameter target:対象のDictionary
      - returns: NSDictionaryオブジェクト（空のキーを省いたオブジェクト）
      */
     public func removeEmptyKeyForDictionary(_ target:NSDictionary) -> NSDictionary{
         
         let result = NSMutableDictionary()
         for element in target.keyEnumerator() {
             let str = element as! String
             if !str.isEmpty {
                 result.setValue(target.object(forKey: str), forKey: str)
             }
         }
         return result.copy() as! NSDictionary
     }
     /**
      通信状態チェック
      - returns: 通信可能でtrue
      */
     public func isConnectedToNetwork() -> Bool {
         var zeroAddress = sockaddr_in()
         zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
         zeroAddress.sin_family = sa_family_t(AF_INET)
         guard let defaultRouteReachability = withUnsafePointer(to:&zeroAddress, {
             $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                 SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
             }
         }) else {
             return false
         }
         var flags : SCNetworkReachabilityFlags = []
         if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
             return false
         }
         let isReachable = flags.contains(.reachable)
         let needsConnection = flags.contains(.connectionRequired)
         return (isReachable && !needsConnection)
     }
}
