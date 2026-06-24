import CoreData
import AVFoundation
import AudioToolbox
import SystemConfiguration
import UserNotifications

/**
 CoreData永続化のためのトラッキング情報クラスのパラメータ定義
 */
extension BDashTrackingData {
    @NSManaged var b_id: NSNumber
    @NSManaged var b_unid: String
    @NSManaged var b_log: String
}
/**
 CoreData永続化のためのトラッキング情報クラス
 */
@objc(BDashTrackingData)
public class BDashTrackingData: NSManagedObject, @unchecked Sendable {
    /**
     TrackingData情報を登録する。
     - parameter sendTime: 日付「イベント発生時」
     - parameter sendData: トラッキングデータ
     - returns: なし
     */
    public class func registerBuilderData(_ context:NSManagedObjectContext, sendTime:Int64 ,sendData:BaseBuilder){
        // ログ文字列の生成は Core Data 非依存なので perform 外で行う
        let logString = TrackUtil().dic2json(sendData.mapping2dictionary())
        // insert / プロパティ設定 / save を context 専用キュー上（performAndWait）で同期実行する
        context.performAndWait {
            let trackingData = NSEntityDescription.insertNewObject(forEntityName: BDashConst.kEntityName, into: context) as! BDashTrackingData
            trackingData.b_id = NSNumber(value: sendTime as Int64)
            trackingData.b_unid = UUID().uuidString
            trackingData.b_log = logString
            // 永続化処理
            BDashTrackingManager.sharedManager.saveContext(context)
        }
    }
    
    // 1000件ある場合の削除処理
    // count / fetch / delete / save を context 専用キュー上（performAndWait）で同期実行する。
    class func deleteRemainData(_ context:NSManagedObjectContext) {
        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: BDashConst.kEntityName)
            do {
                // ストレージ内の全件数を取得
                let count = try context.count(for:fetchRequest)
                // 現在のトラッキング情報総件数が1000件より多いなら
                if count > Int(bitPattern: BDashConst.kTrackingMaxData) {
                    //削除すべきデータを取得する（1000件超える古いデータを取得）
                    let remaincounts = count - Int(bitPattern:BDashConst.kTrackingMaxData)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: BDashConst.kIdParam, ascending: true)]
                    fetchRequest.fetchLimit = remaincounts
                    let tempArry = try context.fetch(fetchRequest) as! [BDashTrackingData]
                    //トラッキング情報の削除処理
                    for data in tempArry {
                        context.delete(data)
                    }
                    // 永続化処理
                    BDashTrackingManager.sharedManager.saveContext(context)
                }
            } catch let error as NSError {
                BDashLogger.debug("\(error)")
            }
        }
    }
    /**
     トラッキングIDから検索リストを生成する。
     - parameter trackingId: トラッキングID
     - returns: 検索結果リスト
     */
    public func findListForRequest(_ context:NSManagedObjectContext, trackingId:Int64)-> NSMutableArray {
        let results:NSMutableArray = NSMutableArray()
        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: BDashConst.kEntityName)
            //最大取得件数をセット
            fetchRequest.fetchLimit = Int(bitPattern: BDashConst.kRequestPerCountMax)
            //昇順でリスト生成
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: BDashConst.kIdParam, ascending: true)]
            if trackingId > 0 {
                //条件：指定トラッキングIDより大きい、より新しいトラッキング情報
                let id = NSNumber(value: trackingId as Int64)
                fetchRequest.predicate = NSPredicate(format: BDashConst.kIdParam + " > %@", id)
            }
            do {
                let allList = try context.fetch(fetchRequest) as! [BDashTrackingData]
                for data in allList {
                    results.add(data)
                }
            } catch let error as NSError {
                BDashLogger.debug("\(error)")
            }
        }
        return results
    }
    /**
     from To条件によりトラッキング情報を取得する。
     - parameter fromTrackingId: fromトラッキングID
     - parameter toTrackingId: toトラッキングID
     - returns: 検索結果リスト
     */
    class func findListByBetweenId(_ context:NSManagedObjectContext, fromTrackingId:NSNumber,toTrackingId:NSNumber) -> [BDashTrackingData] {
        var result:[BDashTrackingData] = []
        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: BDashConst.kEntityName)
            //fromトラッキングID　以上　toトラッキングID　以下のトラッキングIDを条件にトラッキング情報リストを生成する。
            fetchRequest.predicate = NSPredicate(format: BDashConst.kIdParam + " BETWEEN {%@,%@}", fromTrackingId, toTrackingId)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: BDashConst.kIdParam, ascending: true)]
            do {
                result = try context.fetch(fetchRequest) as! [BDashTrackingData]
            } catch let error as NSError {
                BDashLogger.debug("\(error)")
            }
        }
        return result
    }
    /**
     BDashTrackingDataの配列によりTrackingData情報を削除
     - parameter context: 永続化用コンテキスト, targets: 削除対象
     - returns: なし
     */
    public class func deleteObjects(_ context:NSManagedObjectContext, targets:[BDashTrackingData]) {
        context.performAndWait {
            for data in targets {
                context.delete(data)
            }
            // 永続化処理
            BDashTrackingManager.sharedManager.saveContext(context)
        }
    }
    /**
     ストレージ内の全TrackingData情報を取得
     - parameter context: 永続化用コンテキスト
     - returns: 検索結果リスト
     */
    public class func allObjects(_ context:NSManagedObjectContext) -> [BDashTrackingData] {
        var results: [BDashTrackingData] = []
        context.performAndWait {
            do {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: BDashConst.kEntityName)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: BDashConst.kIdParam, ascending: true)]
                results = try context.fetch(fetchRequest) as! [BDashTrackingData]
            } catch let error as NSError {
                BDashLogger.debug("\(error)")
            }
        }
        return results
    }
}
