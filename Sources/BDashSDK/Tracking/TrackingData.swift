import Foundation
import CoreData

@objcMembers
public final class TrackingData: NSManagedObject {
    
    nonisolated(unsafe) static let shared = TrackingData()
    
    @NSManaged var b_id: NSNumber
    @NSManaged var b_unid: String
    @NSManaged var b_log: String
    
    nonisolated(unsafe) private var mainContext: NSManagedObjectContext?
    nonisolated(unsafe) private var backgroundContext: NSManagedObjectContext?

    public func getContext() -> NSManagedObjectContext {
        if Thread.current.isMainThread {
            if (mainContext === nil) {
                mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            }
            return mainContext!
        } else {
            if (backgroundContext === nil) {
                backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                backgroundContext?.persistentStoreCoordinator = self.backgroundContext?.persistentStoreCoordinator
                backgroundContext?.undoManager = nil
            }
            return backgroundContext!
        }
    }
    
    public func saveContext(_ context: NSManagedObjectContext){
        context.performAndWait {
            if context.hasChanges {
                do{
                    try context.save()
                } catch let error as NSError {
                    BDashLogger.debug("\(error)")
                }
            }
        }
    }
    
    func registerBuilderData(_ context:NSManagedObjectContext, sendTime:Int64 ,sendData:BaseBuilder){
        
        let trackingData = NSEntityDescription.insertNewObject(forEntityName: BDashConst.kEntityName, into: context) as! TrackingData
        trackingData.b_id = NSNumber(value: sendTime as Int64)
        trackingData.b_unid = UUID().uuidString
        trackingData.b_log = TrackUtil().dic2json(sendData.mapping2dictionary())
        saveContext(context)
    }
    
    // 1000件ある場合の削除処理
    func deleteRemainData(_ context:NSManagedObjectContext) async {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: BDashConst.kEntityName)
        
        do{
            // ストレージ内の全件数を取得
            let count = try context.count(for:fetchRequest)
            // 現在のトラッキング情報総件数が1000件より多いなら
            if count > Int(bitPattern: BDashConst.kTrackingMaxData) {
                //削除すべきデータを取得する（1000件超える古いデータを取得）
                let remaincounts = count - Int(bitPattern:BDashConst.kTrackingMaxData)
                var tempArry:[TrackingData] = []
                
                do {
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: BDashConst.kIdParam, ascending: true)]
                    fetchRequest.fetchLimit = remaincounts
                    tempArry = try context.fetch(fetchRequest) as! [TrackingData]
                } catch let error as NSError {
                    BDashLogger.debug("\(error)")
                }
                //トラッキング情報の削除処理
                deleteObjects(context, targets: tempArry)
            }
        } catch _ as NSError {
            
        }
    }

    func findListForRequest(_ context:NSManagedObjectContext, trackingId:Int64)-> NSMutableArray {
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
        let results:NSMutableArray = NSMutableArray()
        
        do {
            let allList = try context.fetch(fetchRequest) as! [TrackingData]
            
            if allList.count == 0 {
                return results
            }
            for data in allList {
                results.add(data)
            }
        } catch let error as NSError {
            BDashLogger.debug("\(error)")
        }
        return results
    }

    func findListByBetweenId(_ context:NSManagedObjectContext, fromTrackingId:NSNumber,toTrackingId:NSNumber)-> [TrackingData] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: BDashConst.kEntityName)
        //fromトラッキングID　以上　toトラッキングID　以下のトラッキングIDを条件にトラッキング情報リストを生成する。
        fetchRequest.predicate = NSPredicate(format: BDashConst.kIdParam + " BETWEEN {%@,%@}", fromTrackingId, toTrackingId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: BDashConst.kIdParam, ascending: true)]
        var result:[TrackingData] = []
        
        do {
            result = try context.fetch(fetchRequest) as! [TrackingData]
        } catch let error as NSError {
            BDashLogger.debug("\(error)")
        }
        return result
    }

    func deleteObjects(_ context:NSManagedObjectContext, targets:[TrackingData]){
        for data in targets {
            context.delete(data)
        }
        saveContext(context)
    }

    func allObjects(_ context:NSManagedObjectContext)-> [TrackingData] {
        var results: [TrackingData] = []
        do {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: BDashConst.kEntityName)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: BDashConst.kIdParam, ascending: true)]
            results = try context.fetch(fetchRequest) as! [TrackingData]
        } catch let error as NSError {
            BDashLogger.debug("\(error)")
        }
        return results
    }
}
