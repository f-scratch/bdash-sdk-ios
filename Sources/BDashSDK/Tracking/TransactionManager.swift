import Foundation

/// トランザクション状態の管理クラス
final class TransactionManager: Sendable {

    /// トランザクション情報
    struct TransactionInfo {
        let id: String
        let date: Int64
    }

    nonisolated(unsafe) private var transactions: [TransactionInfo] = []
    private let lock = NSLock()

    /// トランザクションを追加
    func add(_ info: TransactionInfo) {
        lock.lock()
        defer { lock.unlock() }
        transactions.append(info)
    }

    /// 指定IDのトランザクションを削除
    func remove(id: String) {
        lock.lock()
        defer { lock.unlock() }
        transactions.removeAll { $0.id == id }
    }

    /// 遅延リクエスト（600秒以上前）を削除
    func removeDelayedRequests(currentTime: Int64) {
        lock.lock()
        defer { lock.unlock() }
        transactions.removeAll { (currentTime - $0.date) > 600000 }
    }

    /// 最大のトラッキングIDを取得
    func getMaxId() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        var maxId: Int64 = 0
        for info in transactions {
            let parts = info.id.components(separatedBy: "_")
            if parts.count == 2, let endId = Int64(parts[1]), endId > maxId {
                maxId = endId
            }
        }
        return maxId
    }

    /// トランザクション数
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return transactions.count
    }
    
    func removeTargetKye(_ searchList:NSMutableArray,target:String){
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

   func removeDelayRequest(_ searchList:NSMutableArray){
       let current = TrackUtil().generateTrackingId()
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

   func parseGetArgments(_ urlStr:String) -> Dictionary<String, String>{
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
}
