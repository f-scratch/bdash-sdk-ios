import Foundation
import CoreData
import AppTrackingTransparency

/// トラッカークラス
/// send / sync を通して、ログ送信処理を行う公開クラス
@objcMembers
public final class Tracker: NSObject, Sendable {

    // MARK: - Public Constants

    /// SDKバージョン
    public static let SDK_VERSION = "7.0.0"
    /// 起動タイプ[ホーム画面など]: boot
    public static let BOOT_BOOT = "boot"
    /// 起動タイプ[通知]: push
    public static let BOOT_PUSH = "push"
    /// 起動タイプ[スキーマ]: schema
    public static let BOOT_SCHEMA = "schema"
    /// 起動タイプ[それ以外]: other
    public static let BOOT_OTHER = "other"

    // MARK: - Public Stored Properties

    /// UUID
    public nonisolated(unsafe) var customId: String!
    /// 表示スクリーン名
    public nonisolated(unsafe) var screenName: String!
    /// ビジターID（セッター）
    public nonisolated(unsafe) var visitorId: String!
    /// IDFA
    public nonisolated(unsafe) var idfa: String!
    /// 起動元:bootType
    public nonisolated(unsafe) var bootType: String! = BOOT_BOOT

    // MARK: - Internal Stored Properties

    /// シリアルキュー
    let serialDispatchQueue = DispatchQueue(label: BDashConst.kTrackingDomain, attributes: [])
    /// arrTransactionInfo:処理中のトランザクションIDリスト
    nonisolated(unsafe) var arrTransactionInfo: NSMutableArray = NSMutableArray()
    /// ログインユーザーID
    public nonisolated(unsafe) var loginUserId: String!
    /// relationalKey:リレーショナルキー
    public nonisolated(unsafe) var relationalKey: String!
    /// relationalValue:リレーショナルバリュー
    public nonisolated(unsafe) var relationalValue: String!
    /// ユーザー情報:アプリ開発者が定義したユーザー情報
    public nonisolated(unsafe) var userMap: NSDictionary!
    /// 起動値：bootValue
    nonisolated(unsafe) var bootValue: String!

    // MARK: - Private Stored Properties

    /// ログ同期状況のステータス状況管理
    nonisolated(unsafe) private var sendState: SendState = SendState.AVAILABLE
    private let sendStateLock = NSRecursiveLock()
    private var sendStateWrapper: SendState {
        get { return self.sendState }
        set {
            defer { sendStateLock.unlock() }
            sendStateLock.lock()
            BDashLogger.debug("tracking log sync process well become \(newValue.rawValue)")
            self.sendState = newValue
        }
    }
    /// ログ同期中の送信タイプ
    nonisolated(unsafe) private var runningSendType: SendType? = nil
    /// リトライ時のカウンタ
    nonisolated(unsafe) private var retryCount: Int = 0 {
        didSet {
            Task { @MainActor in
                if retryCount > 0 {
                    BDashLogger.debug("incremented: retryCount: \(retryCount)")
                }
                if retryCount >= retryMaxWaitCount {
                    BDashLogger.debug("end retry because retryCount has reached the limit")
                }
            }
        }
    }
    /// リトライ回数の最大値
    private let retryMaxWaitCount = 5
    /// リトライ時の待機秒数
    private let retryMaxCountWaitSecond = 0.5
    /// 同期後の残ログ数
    nonisolated(unsafe) private var logCount: Int = 0

    // MARK: - Init

    public override init() {
        super.init()
        setNewLogCountUpdatedBy(processName: "initlize")
    }
}

// MARK: - Public API
extension Tracker {

    /**
     シングルトンオブジェクトを返す
     - returns: Trackerオブジェクト
     */
    public class var sharedInstance: Tracker {
        struct Static {
            static let instance: Tracker = Tracker()
        }
        return Static.instance
    }

    /**
     インスタンスを返す（旧SDK互換: クラスメソッドとして呼び出し可能）
     - returns: Trackerオブジェクト
     */
    public class func getInstance() -> Tracker {
        let tracker = Tracker.sharedInstance
        if tracker.visitorId == nil {
            tracker.visitorId = RootInfoModel().getUUId()
        }
        return tracker
    }

    /// ATT（App Tracking Transparency）同意状態を加味した IDFA を返す。
    ///
    /// iOS 14.5 以降ではユーザーがトラッキングを明示的に許可（`.authorized`）した場合のみ
    /// `idfa` を返し、未承認（`.notDetermined` / `.denied` / `.restricted`）の場合は `nil` を返す。
    /// iOS 14.5 未満では ATT の対象外のため従来どおり `idfa` を返す。
    /// - Returns: 送信してよい IDFA。同意が無い場合は `nil`。
    var attAuthorizedIdfa: String? {
        if #available(iOS 14.5, *) {
            return ATTrackingManager.trackingAuthorizationStatus == .authorized ? self.idfa : nil
        } else {
            return self.idfa
        }
    }

    /// 同期後の残ログ数を取得する
    public func getLogCount() -> Int {
        return self.logCount
    }

    /// 同期後の残ログ数を最新化する
    public func setNewLogCountUpdatedBy(processName: String) {
        Task { @MainActor in
            let beforeCount = self.logCount
            let context = BDashTrackingManager.sharedManager.getContext()
            let afterCount = BDashTrackingData.allObjects(context).count
            self.logCount = afterCount
            BDashLogger.debug("finished \(processName): remain log count is \(beforeCount) -> \(afterCount)")
        }
    }

    /**
     ブートタイプをセットする。
     - parameter type: 起動タイプ
     - parameter value: 起動値（URL）
     */
    public func setBootTypeWithValue(_ type: String, value: URL) {
        self.bootType = type
        if (value.query != nil) {
            let value = value.query!
            self.bootValue = value.removingPercentEncoding
        }
    }

    /**
     ブートタイプをセットする。
     - parameter type: 起動タイプ
     - parameter value: 起動値（String）
     */
    public func setBootTypeWithStringValue(_ type: String, value: String? = nil) {
        self.bootType = type
        self.bootValue = value
    }

    /**
     tracker2Builder：トラッカーメンバーからビルダークラスへの移行メソッド
     - parameter sendData: ビルダー情報
     */
    public func tracker2Builder(_ sendData: BaseBuilder) {
        sendData.screenName = self.screenName
        sendData.loginUserId = self.loginUserId
        sendData.relationalKey = self.relationalKey
        sendData.relationalValue = self.relationalValue
        if self.userMap != nil {
            sendData.userMap = TrackUtil().removeEmptyKeyForDictionary(self.userMap)
        }
        sendData.bootType = self.bootType
        sendData.bootValue = self.bootValue
    }

    /**
     sendメソッド。非同期通信を行ってログ情報を送信する。
     - 前処理：ビルダーオブジェクトにTrackerオブジェクトの情報をマッピング
     - 主処理：ビルダーオブジェクトをキャッシュに登録
     - 通信：asyncSendメソッドをコールする
     - parameter sendData: ビルダー情報
     */
    @MainActor
    public func send(_ sendData: BaseBuilder) {
        let sendType = SendType.SEND

        if self.logCount >= BDashConst.kTrackingMaxData {
            BDashLogger.debug("caution \(sendType.rawValue) : tracking log data is already full")
        }

        // ログ1件を新規追加する
        self.tracker2Builder(sendData)
        self.initRootTrackingInfo()
        // 永続化用コンテキスト取得
        let tempContext = BDashTrackingManager.sharedManager.getContext()
        let sendTime = TrackUtil().generateTrackingId()
        TrackUtil().removeDelayRequest(self.arrTransactionInfo)
        // registerBuilderData は内部の performAndWait で同期的に保存されるため、
        // 完了まで同期的にブロックされる（旧 semaphore による同期待ちは不要）。
        BDashTrackingData.registerBuilderData(tempContext, sendTime: sendTime, sendData: sendData)
        self.setNewLogCountUpdatedBy(processName: sendType.rawValue)

        if !TrackUtil().isConnectedToNetwork() {
            BDashLogger.debug("canceled \(sendType.rawValue) : because network is dis-connection")
            return
        }

        // ログの一括同期処理 (100件毎)
        Task {
            do {
                try await asyncSend(sendType)
            } catch SendBusyException.CANCEL {
                BDashLogger.debug("catch: SendException.CANCEL")
                BDashLogger.debug("canceled \(sendType.rawValue) : because the process is BUSY")
            } catch {
            }
        }
    }

    /**
     syncメソッド。非同期通信を行ってログ情報を送信する。
     - 通信前処理：キャッシュデータからTrackingModelにデータを移す
     - 通信：asyncSendメソッドをコールする
     */
    public func sync() async {
        let sendType = SendType.SYNC

        if !TrackUtil().isConnectedToNetwork() {
            BDashLogger.debug("canceled \(sendType.rawValue) : because network connection is weak")
            return
        }

        retryCount = 0
        var needRetry = false
        repeat {
            needRetry = false
            // ログの一括同期処理 (100件毎)
            do {
                try await asyncSend(sendType)
            } catch SendBusyException.CANCEL {
                BDashLogger.debug("catch: SendException.CANCEL")
                BDashLogger.debug("canceled \(sendType.rawValue) : because the process is BUSY")
            } catch SendBusyException.RETRY {
                BDashLogger.debug("catch: SendException.RETRY")
                BDashLogger.debug("suspend \(sendType.rawValue) : because the process is BUSY")
                retryCount += 1
                if retryCount < retryMaxWaitCount {
                    needRetry = true
                    BDashLogger.debug("retry send: after \(retryMaxCountWaitSecond)")
                    try? await Task.sleep(nanoseconds: UInt64(retryMaxCountWaitSecond * 1_000_000_000))
                }
            } catch {
            }
        } while needRetry
    }
}

// MARK: - Internal
extension Tracker {

    // ログ同期の送信タイプ
    enum SendType: String {
        case SEND = "SEND"
        case SYNC = "SYNC"
    }

    // ログ同期処理のステータス
    enum SendState: String {
        case AVAILABLE = "AVAILABLE" // 受付可能
        case BUSY = "BUSY" // 通信中
    }

    // ログ同期処理エラー
    enum SendBusyException: Error {
        case CANCEL
        case RETRY
    }

    /**
     インスタンスを返す（UUID 指定）
     - parameter UUID: ユニークID
     - returns: Trackerオブジェクト
     */
    class func getInstance(_ UUID: String) -> Tracker {
        let tracker = Tracker.sharedInstance
        tracker.customId = UUID
        if tracker.visitorId == nil {
            tracker.visitorId = RootInfoModel().getUUId()
        }
        return tracker
    }

    /// ルート情報の初期化
    func initRootTrackingInfo() {
        self.loginUserId = nil
        self.relationalKey = nil
        self.relationalValue = nil
        self.userMap = nil
        self.bootType = nil
        self.bootValue = nil
        self.screenName = nil
    }

    /**
     asyncSendメソッド。非同期通信を行ってログ情報を送信する。
     - 通信前：HTTPBodyに詰めるリクエスト情報生成する。
     - 通信後：トランザクションIDを元にTrackingModel情報を削除する。
     - parameter type: 送信タイプ（send／sync）
     */
    func asyncSend(_ sendType: SendType) async throws {
        if self.sendStateWrapper == SendState.BUSY {
            if self.runningSendType == SendType.SEND && sendType == SendType.SYNC {
                // SENDの同期処理中にSYNCを呼び出した場合はリトライを行う
                throw SendBusyException.RETRY
            } else {
                throw SendBusyException.CANCEL
            }
        }
        self.sendStateWrapper = SendState.BUSY
        self.runningSendType = sendType

        let tempContext = BDashTrackingManager.sharedManager.getContext()
        BDashTrackingData.deleteRemainData(tempContext)
        await self.asyncSendInternal(tempContext, sendType: sendType)
    }

    func asyncSendInternal(_ context: NSManagedObjectContext, sendType: SendType) async {
        if sendType == SendType.SEND && self.arrTransactionInfo.count >= BDashConst.kTransactionMax {
            BDashLogger.debug("canceled \(sendType.rawValue) : because arrTransactionInfo.count is lager than or equal to Const.kTransactionMax")
            self.sendStateWrapper = SendState.AVAILABLE
            return
        }

        let maxid = TrackUtil().getMaxId(self.arrTransactionInfo)
        let models = BDashTrackingData.findListForRequest(context, trackingId: maxid)
        let startDate = Date()
        // リクエスト件数をセットする。
        let requestCount = (sendType == SendType.SEND) ? BDashConst.kRequestPerCount : BDashConst.kRequestPerCountForSync

        // トラッキング情報のレコード数とリクエスト件数を比べる
        if UInt(models.count) < requestCount {
            BDashLogger.debug("canceled \(sendType.rawValue) : because The number of logs has not reached the lot for sync")
            self.sendStateWrapper = SendState.AVAILABLE
            return
        }
        let param: NSMutableDictionary = await self.generateRequest(models)
        // トランザクション情報を生成する。
        let info: TransactionInfo = self.generateTransactionInfo(models)
        let request = self.generateURLRequest(param, info)
        // 送信中のトランザクション情報を保持する。
        self.arrTransactionInfo.add(info)

        // 送信予定のトラッキングデータリストをログ出力する
        BDashLogger.debug(param.debugDescription)
        //送信タスクの生成
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: {
            data, response, error in do {
                Task { @Sendable in
                    guard let urlString = request.url?.absoluteString else { return }
                    let dic = TrackUtil().parseGetArgments(urlString)
                    guard let transactionId = dic["transactionId"] else { return }
                    TrackUtil().timeInterval(startDate, transactionId: transactionId)
                    if error == nil, let statusCode = (response as? HTTPURLResponse)?.statusCode {
                        // statusCodeが200の場合のみ成功と判断
                        if (statusCode == 200) {
                            Task { @MainActor in
                                if let data = data {
                                    BDashLogger().debugData(data)
                                }
                            }
                            let tempContext = BDashTrackingManager.sharedManager.getContext()
                            // トラッキングIDをfrom toにセパレートする。
                            let tanIds = transactionId.components(separatedBy: "_")
                            if tanIds.count > 1,
                               // fromトラッキングID
                               let transactionId1 = NumberFormatter().number(from: tanIds[0]),
                               // toトラッキングID
                               let transactionId2 = NumberFormatter().number(from: tanIds[1]) {
                                // fromトラッキングID toトラッキングIDを条件にトラッキング情報取得
                                let findList = BDashTrackingData.findListByBetweenId(tempContext, fromTrackingId: transactionId1, toTrackingId: transactionId2)
                                // データが存在するなら
                                if findList.count > 0 {
                                    // トラッキング情報を削除
                                    BDashTrackingData.deleteObjects(tempContext, targets: findList)
                                }
                            }
                        } else {
                            Task { @MainActor in
                                BDashLogger.debug("Failed to send tracking data.  Status code: \(statusCode)")
                            }
                        }
                    } else {
                        Task { @MainActor in
                            BDashLogger.debug("Failed to send tracking data. Error!: \(String(describing: error)).")
                        }
                    }
                    // 送信中のトランザクションIDを削除して、「送信前」の状態に戻す
                    Task { @MainActor in
                        TrackUtil().removeTargetKye(self.arrTransactionInfo, target: String(transactionId))
                        self.sendStateWrapper = SendState.AVAILABLE
                        self.runningSendType = nil
                        self.setNewLogCountUpdatedBy(processName: sendType.rawValue)
                    }
                    // リクエストの前後で一定の時間間隔を確保
                    if #available(iOS 16.0, *) {
                        try? await Task.sleep(for: .seconds(0.5))
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
        })
        // タスク実行
        task.resume()
    }

    /**
     トラッキングログ同期用URLを生成する
     - parameter param: トラッキングログのjson情報
     - parameter info: トランザクション情報
     - returns: サーバーリクエストURL
     */
    func generateURLRequest(_ param: NSMutableDictionary,
                            _ info: TransactionInfo) -> NSMutableURLRequest {
        let baseUrl: String!
        if BDashConst.kServerUrl.contains("?") {
            baseUrl = BDashConst.kServerUrl + "&" + "transactionId=" + info.id
        } else {
            baseUrl = BDashConst.kServerUrl + "?" + "transactionId=" + info.id
        }
        let urlObj: URL = URL(string: baseUrl)!
        let request: NSMutableURLRequest = NSMutableURLRequest(url: urlObj)
        request.httpMethod = "POST"
        // http通信のヘッダーを編集する。
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("bdash-sdk / ver=\(Tracker.SDK_VERSION)", forHTTPHeaderField: "User-Agent")
        // リクエストボディの生成
        request.httpBody = TrackUtil().dic2jsonData(param)
        request.timeoutInterval = BDashConst.kRequestPerLimitTime
        return request
    }

    /**
     リクエスト情報を生成する。
     - parameter findList: TrackingModel情報リスト
     - returns: json情報（ディクショナリオブジェクト）
     */
    func generateRequest(_ findList: NSMutableArray) async -> NSMutableDictionary {
        let dictionaryBase = await RootInfoModel().buildRootInfo(self.customId)
        let arr = dictionaryBase.object(forKey: "trackings") as! NSMutableArray
        for value in findList {
            let model = value as! BDashTrackingData
            arr.add(TrackUtil().json2Dictionary(model.b_log))
        }
        dictionaryBase.setValue(arr, forKey: "trackings")
        return dictionaryBase
    }

    /**
     TrackingModel情報をからTransactionInfoを生成する。
     - parameter findList: Tracking情報リスト
     - returns: TransactionInfo
     */
    func generateTransactionInfo(_ findList: NSMutableArray) -> TransactionInfo {
        let transactionId = TrackUtil().generateTrasactionId(findList)
        let info = TransactionInfo()
        info.id = transactionId
        info.date = TrackUtil().generateTrackingId()
        return info
    }
}
