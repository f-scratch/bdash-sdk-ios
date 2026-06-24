import CoreData

public class BDashTrackingManager {

    public nonisolated(unsafe) static var sharedManager: BDashTrackingManager = {
        return BDashTrackingManager()
    }()

    fileprivate init() {}
    
    
    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.f-scratch.bdash.mobile.analytics.BDashMobileSDK" in the application's documents Application Support directory.
        //ディレクトリの有無を調べる
        let fileManager = FileManager.default
        let libraryPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0] as String
        //iCloudバックアップ対象かつユーザーからは見えないパスを設定
        let path = libraryPath + "/" + BDashConst.kSqliteDirName
        var isDir : ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDir)
        
        //パスからNSURLを作成
        var url = URL(fileURLWithPath: path)

        //ディレクトリが存在しない場合は作成
        if !isDir.boolValue{
            do {
                // ディレクトリ作成時にファイル保護属性を指定し、配下のファイル（SQLite 本体・-shm・-wal）に
                // 保護クラスを継承させる。
                let directoryAttributes: [FileAttributeKey: Any] = [
                    .protectionKey: FileProtectionType.complete
                ]
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: directoryAttributes)
            } catch let error as NSError {
                BDashLogger.debug("\(error)")
            }
        }

        // SQLite ディレクトリを iCloud・ローカルバックアップ対象から除外する。
        // ディレクトリ単位で除外することで .sqlite / .sqlite-shm / .sqlite-wal の 3 ファイルをまとめて確実に除外する。
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)
        } catch let error as NSError {
            BDashLogger.debug("\(error)")
        }

        return url
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // SDKパッケージ自身のリソースバンドルからCoreDataモデルを読み込む
        // （アプリ側に同梱せず、SwiftPMのリソース機構で完結させる）
        let modelURL = Bundle.module.url(forResource: "BDashMobileSDK", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent(BDashConst.kSqliteFileName)
        var failureReason = "There was an error creating or loading the application's saved data."
        // SQLite ストアにファイル保護クラスを適用する。
        let storeOptions: [String: Any] = [
            NSPersistentStoreFileProtectionKey: FileProtectionType.complete
        ]
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: storeOptions)
        } catch {
        }
        
        return coordinator
    }()
    
    // 永続化用の単一コンテキスト（privateQueue）。
    // 全てのCore Data操作は、このコンテキストの perform / performAndWait 経由で実行する。
    // mainContext / backgroundContext の二本立てを廃止し単一に集約することで、
    // 同一データに対する2コンテキスト分裂（未保存変更の不整合・データ競合）を解消する。
    lazy var dataContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = self.persistentStoreCoordinator
        context.undoManager = nil
        return context
    }()

    // コンテキストの取得メソッド
    // 呼び出しスレッドに依らず常に同一の privateQueue コンテキストを返す。
    public func getContext() -> NSManagedObjectContext {
        return self.dataContext
    }
    
    /**
     CoreDataの永続化処理
     */
    func saveContext(_ context: NSManagedObjectContext){
        if context.hasChanges {
            do{
                try context.save()
            } catch let error as NSError {
                BDashLogger.debug("\(error)")
            }
        }
    }
}
