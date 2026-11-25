import CoreData

public class BDashTrackingManager {

    public nonisolated(unsafe) static var sharedManager: BDashTrackingManager = {
        return BDashTrackingManager()
    }()
    
    var existPersistentContainer = false

    fileprivate init() {}

    lazy var persistentContainer: NSPersistentContainer = {
        guard let modelURL = Bundle.module.url(forResource: "BDashMobileSDK", withExtension: "momd"),
              let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            BDashLogger.debug("BDashMobileSDK model cannot be found.")
            // SPMにない場合は暫定的にアプリのBundleのmodelを参照する
            return NSPersistentContainer(name: "BDashMobileSDK")
        }
        let container = NSPersistentContainer(name: "BDashMobileSDK", managedObjectModel: managedObjectModel)
        let path = container.persistentStoreDescriptions.last?.url ?? URL(fileURLWithPath: "/dev/null")
        let description = NSPersistentStoreDescription(url: path)
        description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { storeDescription, error in
            if error != nil {
                BDashLogger.debug("There was an error creating or loading the application's saved data.")
                self.existPersistentContainer = false
            } else {
                self.existPersistentContainer = true
            }
        }
        
        return container
    }()

    public func getContext() -> NSManagedObjectContext {
        if Thread.current.isMainThread {
            return persistentContainer.viewContext
        } else {
            return persistentContainer.newBackgroundContext()
        }
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
