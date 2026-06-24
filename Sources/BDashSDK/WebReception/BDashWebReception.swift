import Foundation
import WebKit

public let waitSwitchKey = "waitSwitchKey"
nonisolated(unsafe) var sizeUnitSetting = "auto"

public struct BDashConstStruct {
    public static let isReactNative: Bool = false // ReactNative版の場合trueにする

    public static let baseUrl: String = "https://receptions.bdash.works/"
    public static let settingJsonFile: String = "v2/mobile/receptions"

    public static let javaScriptSuccessWebView: String = "successWebview()"
    public static let javaScriptOnClose: String = "onClose()"
}

public struct WebReceptionKey {
    /// mobile_web_reception API リクエスト Jsonプロパティ名
    static let accessType: String = "accessType" // アクセスタイプ
    static let targets: String = "targets" // 対象となるターゲット
    static let trigger: String = "trigger" // 発生したトリガー
    static let view: String = "view" // 現在のスクリーン名
    static let page: String = "page"  // 現在のページ
    static let preView: String = "preView" // 直前のスクリーン名
    static let prePage: String = "prePage" // 直前のページ
    static let eventFunc: String = "eventFunc" // イベント関数名
    static let customProperty: String = "customProperty" // カスタム用
    
    /// mobile_web_reception API レスポンス Jsonプロパティ名
    static let target: String = "target" // ターゲット
    static let scrollConditions: String = "scrollConditions" // スクロール時の表示条件
    static let url: String = "url" // WebView URL
    static let allowClick: String = "allowClick" // 後ろのコンテンツをクリックできるか
    static let useFilter: String = "useFilter" // 画面フィルターをかけるか
    static let effect: String = "effect" // エフェクト
    static let effectDuration: String = "effectDuration" // エフェクト演出時間
    static let verticalAlign: String = "verticalAlign" // 縦の表示位置
    static let horizontalAlign: String = "horizontalAlign" // 横の表示位置
    static let verticalMargin: String = "verticalMargin" // 縦のマージン
    static let horizontalMargin: String = "horizontalMargin" // 横のマージン
    static let width: String = "width" // 横幅
    static let height: String = "height" // 縦幅
    static let widthPx: String = "widthPx" // タブレット用の横幅px指定
    static let heightPx: String = "heightPx" // タブレット用の縦幅px指定
    
    static let closeButtonVerticalAlign: String = "closeButtonVerticalAlign" // 閉じるボタンの上辺からの距離(単位はpx)
    static let closeButtonHorizontalAlign: String = "closeButtonHorizontalAlign" // 閉じるボタンの左辺からの距離(単位はpx)
    static let closeButtonHeight: String = "closeButtonHeight" // 閉じるボタンの縦幅のサイズ(単位はpx)
    static let closeButtonWidth: String = "closeButtonWidth" // 閉じるボタンの横幅をサイズ(単位はpx)
    static let closeButtonSrc: String = "closeButtonSrc" // 閉じるボタンの画像のパス
    
    static let forceShow: String = "forceShow"
}

/// レイアウト指定 key
fileprivate struct LayoutKey {
    static let center: String = "center" // 真ん中基準位置
    static let top: String = "top" // 上部基準位置
    static let bottom: String = "bottom" // 下部基準位置
    static let left: String = "left" // 左側基準位置
    static let right: String = "right" // 右側基準位置
}

/// エフェクト key
fileprivate struct EffectKey {
    // nullや定義がなければ演出なし(default)
    static let fadein: String = "fadein" // フェードイン
}

//MARK: - enum

enum popupStatusType: Int {
    case initial        // 初期状態
    case callingApi     // API call中
    case showing        // ポップアップ表示中
}

enum reportStatus: Int {
    case notCalling     // APIコール前
    case calling        // APIコール中
}

// 埋め込みWEB接客のステータス
enum getWebReceptionStatusType: Int {
    case initial        // 初期状態
    case callingApi     // API call中
}

enum accessType: String {
    // embeddingは埋め込みWEB接客
    case boot = "boot"
    case update = "update"
    case embedding = "embedding"
    case tracking = "tracking"
}

public enum eventType: Int {
    case EVENT_INTERNAL = 0
    case EVENT_WEBVIEW
}

enum queueObjType: String {
    case showMessage = "showMessage"
    case report = "report"
    case getWebReception = "getWebReception"
}

enum commandType: String {
    case close = "close"
    case copy = "copy"
}

// MARK: - param

/// Web接客顧客設定取得APIレスポンス
struct CustomerSettingResponseParam {
    let target: String
    let scrollConditions: String?
    let url: String
    let allowClick: String
    let useFilter: String
    let effect: String
    var effectDuration: Double
    let forceShow: Bool?
    
    let verticalAlign: String
    let horizontalAlign: String
    let verticalMargin: CGFloat
    let horizontalMargin: CGFloat
    let width: CGFloat
    let height: CGFloat
    let widthPx: CGFloat
    let heightPx: CGFloat
    
    let closeButtonVerticalAlign: CGFloat
    let closeButtonHorizontalAlign: CGFloat
    let closeButtonHeight: CGFloat
    let closeButtonWidth: CGFloat
    let closeButtonSrc: String
    
    init(dic: [AnyHashable: Any]) {
        target = dic[WebReceptionKey.target] as? String ?? ""
        scrollConditions = dic[WebReceptionKey.scrollConditions] as? String
        url = dic[WebReceptionKey.url] as? String ?? ""
        allowClick = (dic[WebReceptionKey.allowClick] as? String) ?? "true"
        useFilter = (dic[WebReceptionKey.useFilter] as? String) ?? "false"
        effect = dic[WebReceptionKey.effect] as? String ?? ""
        effectDuration = 2.0
        if let duration = dic[WebReceptionKey.effectDuration] as? String {
            if let value = Double(duration) {
                if 0 <= value && value < 3.1 {
                    effectDuration = value
                }
            }
        }
        if let boolStr = dic[WebReceptionKey.forceShow] as? String {
            self.forceShow = Bool(boolStr)
        } else {
            self.forceShow = nil
        }
        
        verticalAlign = (dic[WebReceptionKey.verticalAlign] as? String ?? LayoutKey.center).lowercased()
        horizontalAlign = (dic[WebReceptionKey.horizontalAlign] as? String ?? LayoutKey.center).lowercased()
        if let verticalMarginStr = dic[WebReceptionKey.verticalMargin] as? String, let verticalMargin = CGFloat(verticalMarginStr) {
            self.verticalMargin = verticalMargin
        } else {
            self.verticalMargin = 0.0
        }
        if let horizontalMarginStr = dic[WebReceptionKey.horizontalMargin] as? String, let horizontalMargin = CGFloat(horizontalMarginStr) {
            self.horizontalMargin = horizontalMargin
        } else {
            self.horizontalMargin = 0.0
        }
        
        var tmpWidth: Int = 100
        if let widthStr = dic[WebReceptionKey.width] as? String {
            let res = widthStr.components(separatedBy: ",")
            if res.count > 1 {
                if let width = Int(res[0]) {
                    if width < 10 {
                        tmpWidth = 10
                    } else if width >= 100 {
                        tmpWidth = 100
                    } else {
                        tmpWidth = width
                    }
                }
            } else {
                if let width = Int(widthStr) {
                    if width < 10 {
                        tmpWidth = 10
                    } else if width >= 100 {
                        tmpWidth = 100
                    } else {
                        tmpWidth = width
                    }
                }
            }
        }
        self.width = CGFloat(integerLiteral: tmpWidth) / 100.0
        
        var tmpHeight: CGFloat = 1.0
        if let heightStr = dic[WebReceptionKey.height] as? String, let height = CGFloat(heightStr) {
            if height < 0.1 {
                tmpHeight = 0.1
            } else if height >= 3.0 {
                tmpHeight = 3.0
            } else {
                tmpHeight = height
            }
        }
        self.height = tmpHeight
        
        if let widthPxStr = dic[WebReceptionKey.widthPx] as? String, let widthPx = CGFloat(widthPxStr) {
            self.widthPx = widthPx
        } else {
            self.widthPx = 0
            sizeUnitSetting = "vw"
        }

        if let heightPxStr = dic[WebReceptionKey.heightPx] as? String, let heightPx = CGFloat(heightPxStr) {
            if heightPx > self.widthPx * 3 {
                self.heightPx = self.widthPx * 3
            } else {
                self.heightPx = heightPx
            }
        } else {
            self.heightPx = 0
            sizeUnitSetting = "vw"
        }
        
        if self.widthPx == 0 || self.heightPx == 0 {
            sizeUnitSetting = "vw"
        }

        // アプリ接客コンテンツの上辺からの距離
        var tmpCloseButtonVerticalAlign: CGFloat = 1.0
        if let closeButtonVerticalAlignStr = dic[WebReceptionKey.closeButtonVerticalAlign] as? String, let closeButtonVerticalAlign = CGFloat(closeButtonVerticalAlignStr) {
            tmpCloseButtonVerticalAlign = closeButtonVerticalAlign
        }
        self.closeButtonVerticalAlign = tmpCloseButtonVerticalAlign / 100.0

        // アプリ接客コンテンツの左辺からの距離
        var tmpCloseButtonHorizontalAlign: CGFloat = 1.0
        if let closeButtonHorizontalAlignStr = dic[WebReceptionKey.closeButtonHorizontalAlign] as? String, let closeButtonHorizontalAlign = CGFloat(closeButtonHorizontalAlignStr) {
            tmpCloseButtonHorizontalAlign = closeButtonHorizontalAlign
        }
        self.closeButtonHorizontalAlign = tmpCloseButtonHorizontalAlign / 100.0

        // 閉じるボタンの縦幅のサイズ
        var tmpCloseButtonHeight: CGFloat = 1.0
        if let closeButtonHeightStr = dic[WebReceptionKey.closeButtonHeight] as? String, let closeButtonHeight = CGFloat(closeButtonHeightStr) {
            tmpCloseButtonHeight = closeButtonHeight
        }
        self.closeButtonHeight = tmpCloseButtonHeight

        // 閉じるボタンの横幅のサイズ
        var tmpCloseButtonWidth: CGFloat = 1.0
        if let closeButtonWidthStr = dic[WebReceptionKey.closeButtonWidth] as? String, let closeButtonWidth = CGFloat(closeButtonWidthStr) {
            tmpCloseButtonWidth = closeButtonWidth
        }
        self.closeButtonWidth = tmpCloseButtonWidth / 100.0

        // 閉じるボタンの画像のパス
        self.closeButtonSrc = dic[WebReceptionKey.closeButtonSrc] as? String ?? ""
    }
}

struct ShowMsgObj : Sendable {
    let report: BDashReport
    let view: UIView
    var baseUrl: String = ""
    var jsonFile: String = ""
    
    init(report: BDashReport, view: UIView) {
        self.report = report
        self.view = view
    }
    
    mutating func setJsonUrl(baseUrl: String?, jsonFile: String?) {
        self.baseUrl = baseUrl ?? ""
        self.jsonFile = jsonFile ?? ""
    }
}

struct ReportObj {
    let report: BDashReport
    var baseUrl: String = ""
    var jsonFile: String = ""
    
    init(report: BDashReport) {
        self.report = report
    }
    
    mutating func setJsonUrl(baseUrl: String?, jsonFile: String?) {
        self.baseUrl = baseUrl ?? ""
        self.jsonFile = jsonFile ?? ""
    }
}

// 埋め込みWEB接客のオブジェクト
struct GetWebReceptionObj : Sendable {
    let report: BDashReport
    let view: UIView
    var baseUrl: String = ""
    var jsonFile: String = ""
    
    init(report: BDashReport, view: UIView) {
        self.report = report
        self.view = view
    }
    
    mutating func setJsonUrl(baseUrl: String?, jsonFile: String?) {
        self.baseUrl = baseUrl ?? ""
        self.jsonFile = jsonFile ?? ""
    }
}

struct WebReceptionBootResponse {
    let allowClick: Bool
    
    init(info: [AnyHashable: Any]) {
        allowClick = info[WebReceptionKey.allowClick] as? Bool ?? true
    }
}

// MARK: - BDashWebReception Class
@objcMembers
public final class BDashWebReception: NSObject, Sendable {
    
    nonisolated(unsafe) fileprivate var popupView: PopupView?
    nonisolated(unsafe) fileprivate var mCsrp: CustomerSettingResponseParam?
    nonisolated(unsafe) fileprivate var mTmpSafeArea: UIEdgeInsets?
    
    nonisolated(unsafe) fileprivate var statusCode: Int = 200
    fileprivate let effect: String = ""
    fileprivate let effectDuration: Double = 2.0
    
    nonisolated(unsafe) fileprivate var overwrittenBaseUrls: [String] = []
    nonisolated(unsafe) fileprivate var overwrittenJsonFiles: [String] = []
    
    /// taskQueueを排他的に操作するためのロックオブジェクト
    nonisolated(unsafe) fileprivate var taskQueueSyncObject: AnyObject = NSObject()
    nonisolated(unsafe) fileprivate var taskQueue: [ShowMsgObj] = []
    nonisolated(unsafe) fileprivate var currentTask: ShowMsgObj?
    
    /// reportQueueを排他的に操作するためのロックオブジェクト
    nonisolated(unsafe) fileprivate var reportQueueSyncObject: AnyObject = NSObject()
    nonisolated(unsafe) fileprivate var reportQueue: [ReportObj] = []
    nonisolated(unsafe) fileprivate var currentReport: ReportObj?

    /// getWebReceptionQueue(埋め込みWEB接客)を排他的に操作するためのロックオブジェクト
    nonisolated(unsafe) fileprivate var getWebReceptionQueueSyncObject: AnyObject = NSObject()
    nonisolated(unsafe) fileprivate var getWebReceptionQueue: [GetWebReceptionObj] = []
    nonisolated(unsafe) fileprivate var currentGetWebReception: GetWebReceptionObj?
    
    nonisolated(unsafe) fileprivate var popupStatus: popupStatusType = .initial {
        didSet {
            // ポップアップが「表示中/API待ち」から「存在しない」状態へ戻ったときだけ通知する。
            // 閉じる操作・配信対象0件・API失敗など全経路でこの遷移を通るため、ここ1箇所で検知できる。
            if oldValue != .initial, popupStatus == .initial {
                onPopupClosed?()
            }
        }
    }
    nonisolated(unsafe) fileprivate var forceShow: Bool = false
    nonisolated(unsafe) fileprivate var reportStatus: reportStatus = .notCalling
    // 埋め込みWEB接客のステータス
    nonisolated(unsafe) fileprivate var getWebReceptionStatus: getWebReceptionStatusType = .initial
    
    nonisolated(unsafe) fileprivate var updateConnectionTask: URLSessionDataTask?
    nonisolated(unsafe) fileprivate var scheme: String?
    nonisolated(unsafe) fileprivate var webViewSession: URLSession?
    
    /// エンドユーザーのイベント通知を受け取るためのリスナーを設定する
    /// SDK 顧客提供API showMessageで使用
    public nonisolated(unsafe) var eventDelegate: (@Sendable (_ type: Int, _ param: [AnyHashable: Any]) -> ())?
    
    /// エンドユーザーのイベント通知を受け取るためのリスナーを設定する
    /// SDK 顧客提供API で使用 getWebReceptionで使用
    public nonisolated(unsafe) var getWebReceptionEventDelegate: (@Sendable (_ type: Int, _ param: [AnyHashable: Any]) -> ())?

    /// ポップアップ（showMessage）が「画面に存在しない」状態に戻ったことを通知するリスナー。
    /// 閉じる操作・配信対象0件・API失敗・WebView失敗など、popupStatusが.initialへ戻る全経路で発火する。
    /// SwiftUI オーバーレイラッパーが表示状態（isPresented）を同期するために使用する。
    public nonisolated(unsafe) var onPopupClosed: (@Sendable () -> ())?

    /// 顧客設定 API のレスポンスから `allowClick`（ポップアップ背面のタップ透過可否）が確定したことを通知するリスナー。
    /// SwiftUI オーバーレイラッパーが透明ホストの hitTest 挙動を切り替えるために使用する。
    /// `allowClick` は非同期 API 成功時点で初めて判明するため、確定値をこのコールバックで払い出す。
    public nonisolated(unsafe) var onPopupAllowClickResolved: (@Sendable (Bool) -> ())?

    static fileprivate let reporter: BDashWebReception = {
        BDashWebReception()
    }()
    
    // MARK: - public methods
    
    public override init() {
        super.init()
        BDashLogger.debug("BDashWebReception init")
    }
    
    deinit {
        Task { @MainActor in
            BDashLogger.debug("BDashWebReception deinit")
        }
    }
    
    /// 関数仕様書 (F)Web接客/showMessage
    /// SDK 顧客提供API
    ///
    /// - Parameters:
    ///   - report: レポートデータを管理するモデル
    ///   - onView: showMessageを描画するUIView
    /// - Returns: BDashWebReceptionクラス
    @MainActor
    public func showMessage(report: BDashReport, onView: UIView, sizeUnit: String = "auto") -> BDashWebReception {
        if sizeUnit == "auto" {
            if UIDevice.current.userInterfaceIdiom == .pad {
                sizeUnitSetting = "px"
            } else {
                sizeUnitSetting = "vw"
            }
            
        } else if sizeUnit == "px" || sizeUnit == "vw" {
            sizeUnitSetting = sizeUnit
        } else {
            sizeUnitSetting = "vw"
        }
        if self.popupStatus.rawValue < popupStatusType.showing.rawValue {
            BDashLogger.debug("[showMessage Queue] popup未表示 キューに追加")
            DispatchQueue(label: "jp.co.f-scratch.showMessage").sync {
                self.enqueue(obj: ShowMsgObj(report: report, view: onView))
                Task {
                    await self.runShowMessageQueueTask()
                }
            }
            return self
        } else {
            BDashLogger.debug("[showMessage Queue] popup表示中 処理をreturn")
            return self
        }
    }

    /// 関数仕様書 (F)Web接客/closeMessage
    @MainActor
    public func closeMessage() {
        BDashLogger.debug("[showMessage Queue] closeMessage")
        BDashLogger.debug("===============")

        BDashLogger.debug("\(self.extractSubviewCount() as Any)")
        BDashLogger.debug("===============")
        
        // showMessage Queueをクリア
        self.currentTask = nil
        self.taskQueue.removeAll()
        
        // Updateキャンセル
        if self.updateConnectionTask?.state == .running {
            self.updateConnectionTask?.cancel()
        }

        if let webView = self.popupView?.webView {
            // POSTキャンセル
            self.webViewSession?.invalidateAndCancel()
            
            if webView.isLoading == true {
                webView.stopLoading()
            }
            
            let completion: () -> () = {
                // webViewがnilかどうかで再表示できるかどうか決まるため、失敗時はnilをセットする
                self.popupView?.webView = nil
                self.popupStatus = .initial
                BDashLogger.debug("[showMessage Queue] status更新: \(self.popupStatus)")
                self.popupView?.removeFromSuperview()
            }
            
            self.popupView?.alpha = 0.0
            completion()
        }
    }
    
    /// 関数仕様書 (F)Web接客/copyMessage
    func copyMessage(copyStr: String?) {
        let decodedStr = copyStr?.removingPercentEncoding
        BDashLogger.debug("[command copy] string to clipboard. message:\(String(describing: decodedStr))")
        UIPasteboard.general.string = decodedStr
        self.showAlert(title: "コピー完了", body: "テキストをコピーしました")
    }
    
    /// 関数仕様書 (F)Web接客/report
    /// SDK 顧客提供API
    ///
    /// - Parameter obj: レポートデータを管理するモデル
    /// - Returns: BDashWebReceptionクラス
    public func report(obj: BDashReport) -> BDashWebReception {
        BDashLogger.debug("[report Queue] report called")
        BDashLogger.debug("[report Queue] reportをキューに追加する\(String(describing: obj.customProperty))")
        DispatchQueue(label: "jp.co.f-scratch.report").sync {
            BDashWebReception.reporter.enqueue(obj: ReportObj(report: obj))
            Task {
                await BDashWebReception.reporter.runReportQueueTask()
            }
        }
        return BDashWebReception.reporter
    }
    
    /// 埋め込みWeb接客/getWebReception
    /// SDK 顧客提供API
    ///
    /// - Parameters:
    ///   - report: レポートデータを管理するモデル
    ///   - onView: getWebReceptionを描画するUIView
    /// - Returns: WEB接客のHTMLの文字列
    public func getWebReception(report: BDashReport, onView: UIView) async -> String {
        if self.getWebReceptionStatus == .initial {
            BDashLogger.debug("[getWebReception Queue] webReception未表示 キューに追加")
        } else {
            // getWebReceptionStatusがinitial以外の場合、後続の処理で動かなくなるのでinitialに再設定
            getWebReceptionStatus = .initial
            BDashLogger.debug("[getWebReception Queue] getWebReceptionStatusをinitialに再設定")
        }
        
        // WEB接客のHTML文字列の取得を開始
        return await withCheckedContinuation { continuation in
            DispatchQueue(label: "jp.co.f-scratch.getWebReception").sync {
                self.enqueue(obj: GetWebReceptionObj(report: report, view: onView))
                Task {
                    let htmlString = await self.runGetWebReceptionQueueTask()
                    continuation.resume(returning: htmlString)
                }
            }
        }
    }
    
    //MARK: - private methods
    
    fileprivate func getParameter(param: Any?) -> String? {
        if let param = param, let tmpParam = param as? String, tmpParam.count > 0 {
            return tmpParam
        } else {
            return nil
        }
    }
    
    fileprivate func getCommonParameter() async -> [AnyHashable: Any] {
        let debugDictionary = await RootInfoModel().buildRootInfo("");
        
        var dic: [AnyHashable: Any] = [:]
        
        //デバイスID
        if let deviceId = getParameter(param: debugDictionary["deviceId"]) {
            dic["deviceId"] = deviceId
        }
        
        //UUID
        if let uuId = getParameter(param: debugDictionary["uuId"]) {
            dic["uuId"] = uuId
        }
        
        //アプリID
        if let appId = getParameter(param: debugDictionary["appId"]) {
            dic["appId"] = appId
        }
        
        //アカウントID
        if let accountId = getParameter(param: debugDictionary["accountId"]) {
            dic["accountId"] = accountId
        }
        
        //カスタムID
        if let customId = getParameter(param: debugDictionary["customId"]) {
            dic["customId"] = customId
        }
        
        //デバイス設定言語
        if let lang = getParameter(param: debugDictionary["lang"]) {
            dic["lang"] = lang
        }
        
        //キャリア名
        if let carrier = getParameter(param: debugDictionary["carrier"]) {
            dic["carrier"] = carrier
        }
        
        //アプリバージョン
        if let appVersion = getParameter(param: debugDictionary["appVersion"]) {
            dic["appVersion"] = appVersion
        }
        
        //デバイスOS名
        if let os = getParameter(param: debugDictionary["os"]) {
            dic["os"] = os
        }
        
        //デバイスOSバージョン
        if let osVersion = getParameter(param: debugDictionary["osVersion"]) {
            dic["osVersion"] = osVersion
        }
        
        //デバイスモデル名
        if let model = getParameter(param: debugDictionary["model"]) {
            dic["model"] = model
        }
        
        //デバイス解像度
        if let display = getParameter(param: debugDictionary["display"]) {
            dic["display"] = display
        }
        
        //IDFA
        if let idfa = getParameter(param: debugDictionary["idfa"]) {
            dic["idfa"] = idfa
        }
        
        //データービュー
        if let dataViewIds = getParameter(param: debugDictionary["dataViewIds"]) {
            dic["dataViewIds"] = dataViewIds
        }
        
        return dic
    }
    
    /// 顧客設定 取得APIをコールします
    /// SDK 内部API
    ///
    /// - Parameters:
    ///   - msgObj: showMessage情報
    ///   - success: API成功処理
    ///   - failure: API失敗処理
    /// - Returns: cancelするための通信タスク情報
    fileprivate func update(accessType: accessType, json: [AnyHashable: Any], success: @Sendable @escaping (CustomerSettingResponseParam) -> (), failure: @Sendable @escaping (Error?) -> ()) async -> URLSessionDataTask? {
        
        var url: String = ""
        switch accessType {
        case .update:
            guard let baseUrl = self.currentTask?.baseUrl else { return nil }
            guard let jsonFile = self.currentTask?.jsonFile else { return nil }
            
            url = baseUrl + jsonFile
        // 埋め込みWEB接客の処理
        case .embedding:
            guard let baseUrl = self.currentGetWebReception?.baseUrl else { return nil }
            guard let jsonFile = self.currentGetWebReception?.jsonFile else { return nil }
            
            url = baseUrl + jsonFile
        case .tracking:
            guard let baseUrl = self.currentReport?.baseUrl else { return nil }
            guard let jsonFile = self.currentReport?.jsonFile else { return nil }
            
            url = baseUrl + jsonFile
        case .boot:
            url = BDashConstStruct.baseUrl + BDashConstStruct.settingJsonFile
        }
        BDashLogger.debug("顧客設定APIをコールします。accessType:\(accessType.rawValue) url:\(url)")
        
        let merged = await json.merging(self.getCommonParameter()) { (first, second) -> Any in
            return first
        }
        
        var jsonData: Data?
        var tmpJson = merged
        tmpJson.updateValue(accessType.rawValue, forKey: WebReceptionKey.accessType)
        // リクエストの中身のログ出力　※納品版では削除する。
        BDashLogger.debug("リクエストの中身（tmpJson）: \(tmpJson)")
        do {
            jsonData = try JSONSerialization.data(withJSONObject: tmpJson, options: .prettyPrinted)
        } catch {
            BDashLogger.debug("json error")
        }
        
        if accessType == .update && self.popupStatus != .callingApi {
            // APIコール中にcloseMessageが呼ばれた場合
            BDashLogger.debug("no action")
            return nil
        }
        
        return post(urlString: url, json: jsonData, success: { (data) in
            do {
                if let data = data as? Data {
                    let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves)
                    if let dic = json as? [AnyHashable: Any], let reception = dic["receptions"], let settings = reception as? [[AnyHashable: Any]] {
                        // receptions が空配列 = 配信対象なしの正常系。キューをクリアして終了する。
                        if settings.isEmpty {
                            if accessType == .embedding {
                                Task { @MainActor in
                                    await self.embeddingNoReceptionProcess()
                                }
                            } else {
                                Task { @MainActor in
                                    await self.updateNoReceptionProcess()
                                }
                            }
                            return
                        }
                        let firstSetting = settings[0]
                        let urlValue = firstSetting["url"]
                        if urlValue != nil {
                            Task { @MainActor in
                                success(CustomerSettingResponseParam(dic: settings[0]))
                            }
                        } else {
                            if accessType == .embedding {
                                Task { @MainActor in
                                    await self.embeddingFailureProcess()
                                }
                            } else {

                                Task { @MainActor in
                                    await self.updateFailureProcess()
                                }
                            }
                        }
                        return
                    }
                }
                failure(nil)
            } catch {
                Task { @MainActor in
                    BDashLogger.debug("==ERROR== json format error")
                }
                failure(nil)
            }
        }, failure: { (err) in
            failure(err)
        })
    }
    
    /// showMessage情報をQueueに入れます
    ///
    /// - Parameter obj: showMessage情報
    fileprivate func enqueue(obj: Any) {
        if let obj = obj as? ShowMsgObj {
            self.synchronized(self.taskQueueSyncObject) { [unowned self] in
                var tmpObj = obj
                #if DEBUG
                if self.overwrittenBaseUrls.count >= 1 {
                    tmpObj.setJsonUrl(baseUrl: self.overwrittenBaseUrls.first, jsonFile: self.overwrittenJsonFiles.first)
                    self.overwrittenBaseUrls.removeFirst()
                    self.overwrittenJsonFiles.removeFirst()
                }
                #else
                tmpObj.setJsonUrl(baseUrl: BDashConstStruct.baseUrl, jsonFile: BDashConstStruct.settingJsonFile)
                #endif
                self.taskQueue.append(tmpObj)
            }
        } else if let obj = obj as? ReportObj {
            self.synchronized(self.reportQueueSyncObject) { [unowned self] in
                var tmpObj = obj
                #if DEBUG
                if self.overwrittenBaseUrls.count >= 1 {
                    tmpObj.setJsonUrl(baseUrl: self.overwrittenBaseUrls.first, jsonFile: self.overwrittenJsonFiles.first)
                    self.overwrittenBaseUrls.removeFirst()
                    self.overwrittenJsonFiles.removeFirst()
                }
                #else
                tmpObj.setJsonUrl(baseUrl: BDashConstStruct.baseUrl, jsonFile: BDashConstStruct.settingJsonFile)
                #endif
                self.reportQueue.append(tmpObj)
            }
        // 埋め込みWEB接客の処理
        } else if let obj = obj as? GetWebReceptionObj {
            self.synchronized(self.getWebReceptionQueueSyncObject) { [unowned self] in
                var tmpObj = obj
                #if DEBUG
                if self.overwrittenBaseUrls.count >= 1 {
                    tmpObj.setJsonUrl(baseUrl: self.overwrittenBaseUrls.first, jsonFile: self.overwrittenJsonFiles.first)
                    self.overwrittenBaseUrls.removeFirst()
                    self.overwrittenJsonFiles.removeFirst()
                }
                #else
                tmpObj.setJsonUrl(baseUrl: BDashConstStruct.baseUrl, jsonFile: BDashConstStruct.settingJsonFile)
                #endif
                self.getWebReceptionQueue.append(tmpObj)
            }
        }
    }
    
    /// showMessage情報をQueueから出します
    ///
    /// - Returns: showMessage情報
    fileprivate func dequeue(type: queueObjType) -> Any? {
        if type == .showMessage {
            if self.taskQueue.count > 0 {
                var obj: ShowMsgObj?
                DispatchQueue(label: "jp.co.f-scratch.showMessageDequeue", attributes: []).sync {
                    self.synchronized(self.taskQueueSyncObject) { [unowned self] in
                        obj = self.taskQueue.first
                        self.taskQueue.removeFirst()
                        BDashLogger.debug("[showMessage Queue] showMessage 先頭queueを取出")
                        BDashLogger.debug("url: \(String(describing: obj?.baseUrl))");
                        BDashLogger.debug("json: \(String(describing: obj?.jsonFile))");
                    }
                }
                return obj
            }
        } else if type == .report {
            if self.reportQueue.count > 0 {
                var obj: ReportObj?
                DispatchQueue(label: "jp.co.f-scratch.reportDequeue", attributes: []).sync {
                    self.synchronized(self.reportQueueSyncObject) { [unowned self] in
                        obj = self.reportQueue.first
                        self.reportQueue.removeFirst()
                        BDashLogger.debug("[report Queue] report 先頭queueを取出")
                        BDashLogger.debug("url: \(String(describing: obj?.baseUrl))");
                        BDashLogger.debug("json: \(String(describing: obj?.jsonFile))");
                    }
                }
                return obj
            }
        // 埋め込みWEB接客の処理
        } else if type == .getWebReception {
            if self.getWebReceptionQueue.count > 0 {
                var obj: GetWebReceptionObj?
                DispatchQueue(label: "jp.co.f-scratch.runGetWebReceptionDequeue", attributes: []).sync {
                    self.synchronized(self.getWebReceptionQueueSyncObject) { [unowned self] in
                        obj = self.getWebReceptionQueue.first
                        self.getWebReceptionQueue.removeFirst()
                        BDashLogger.debug("[getWebReception Queue] getWebReception 先頭queueを取出")
                        BDashLogger.debug("url: \(String(describing: obj?.baseUrl))");
                        BDashLogger.debug("json: \(String(describing: obj?.jsonFile))");
                    }
                }
                return obj
            }
        }
        return nil
    }
    
    /// エラー時にQueueの情報を破棄します
    fileprivate func clearQueue() async {
        BDashLogger.debug("[showMessage Queue] clear queue")
        self.synchronized(self.taskQueueSyncObject) { [unowned self] in
            self.taskQueue.removeAll()
        }
    }
    
    /// エラー時に埋め込みWEB接客のQueueの情報を破棄します
    fileprivate func getWebReceptionClearQueue() {
        BDashLogger.debug("[getWebReception Queue] clear queue")
        self.synchronized(self.getWebReceptionQueueSyncObject) { [unowned self] in
            self.getWebReceptionQueue.removeAll()
        }
    }
    
    /// 埋め込みWEB接客にて使用
    /// キューの先頭から一つタスクを取り出し処理し、WEB接客のHTMLを取得
    /// その後、HTML文字列を返す
    fileprivate func runGetWebReceptionQueueTask() async -> String {
        BDashLogger.debug("[getWebReception Queue] runGetWebReceptionQueueTask statusがinitial以外は何もしない")
        BDashLogger.debug("status: \(self.getWebReceptionStatus)")
        if self.getWebReceptionStatus == .initial {
            self.getWebReceptionStatus = .callingApi
            // Queueの先頭から一つ取り出しdeep copy
            if let task = self.dequeue(type: .getWebReception) as? GetWebReceptionObj {
                self.currentGetWebReception = task
                BDashLogger.debug("[getWebReception Queue] status更新: \(self.getWebReceptionStatus)")
                return await withCheckedContinuation { continuation in
                    
                    Task { @Sendable in
                        let reportDic =  await task.report.convertToDic(isSaveToUserDefaults: false)
                        let block: () async -> URLSessionDataTask? = { [unowned self] in
                            // 「accessType: .embedding」= 埋め込みWEB接客
                            return await self.update(accessType: .embedding,
                                                     json:reportDic,
                                                     success: {
                                [weak self] (setting) in
                                    Task { @MainActor in
                                        BDashLogger.debug("[getWebReception Queue] 顧客設定API 成功")
                                    }
                                // Web接客顧客設定取得APIレスポンス
                                self?.mCsrp = setting
                                
                                // UI操作のためメインスレッドで実行
                                Task { @MainActor in
                                    var webViewUrl = task.baseUrl + setting.url
                                    #if DEBUG
                                    if setting.url.hasPrefix("http") {
                                        BDashLogger.debug("[getWebReception Queue] jsonファイル内urlはhttp://から始まるのでbase urlを上書きする")
                                        webViewUrl = setting.url
                                    }
                                    #endif
                                    let htmlString = await self?.getWebReceptionHtml(url: webViewUrl, msgObj: task)
                                    continuation.resume(returning: htmlString ?? "")
                                }
                                
                            }, failure: { [weak self] (err) in
                                // キューを全て破棄
                                Task {
                                    await self?.embeddingFailureProcess()
                                }
                                continuation.resume(returning: "")
                            })
                        }
                        self.updateConnectionTask = await block()
                    }
                }
            } else {
                // 実行すべきタスクがQueueにもうない
                BDashLogger.debug("[getWebReception Queue] queueが空です")
                self.getWebReceptionStatus = .initial
                BDashLogger.debug("[getWebReception Queue] status更新: \(self.getWebReceptionStatus)")
            }
        }
        return ("")
    }
    
    // WEB接客の埋め込みのためのHTML文字列を取得する
    fileprivate func getWebReceptionHtml(url: String, msgObj: GetWebReceptionObj) async -> String {
        
        return await withCheckedContinuation { continuation in
            Task {
                // Web接客・WebViewリクエストAPIを呼出してHTML文字列を取得
                let htmlString = await self.callWebReceptionApi(url: url, msgObj: msgObj)

                continuation.resume(returning: htmlString ?? "")
            }
        }
    }
    
    // Web接客・WebViewAPIをコールしてWEB接客の埋め込みのためのHTML文字列を取得する
    @MainActor
    fileprivate func callWebReceptionApi(url: String, msgObj: GetWebReceptionObj) async -> String? {
        guard let url = URL(string: url) else { return nil }
        BDashLogger.debug("[getWebReception Queue] web view APIをコールします。 url:\(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = BDashConst.kRequestPerLimitTime

        let commonPara = await self.getCommonParameter()
        let reportDic = await msgObj.report.convertToDic(isSaveToUserDefaults: false)
        
        let keyList = ["uuId", "trigger", "view", "preView", "page", "prePage", "eventFunc", "customProperty"]
        var param: [AnyHashable: Any] = [:]

        for key in keyList {
            if key == "uuId" {
                param["uuid"] = commonPara["uuId"] as? String ?? ""
            } else {
                param[key] = reportDic[key]
            }
        }
        // v2 view では AuthenticationFilter が appId を必須として要求するため body に含める
        // accountCode は URL パス側の {code} から取得される設計のため body には含めない
        param["appId"] = commonPara["appId"] as? String ?? ""
        let paramStr = convertToJsonAndUrlEncode(dic: param)
        request.httpBody = paramStr.data(using: .utf8)
        let request_body: String = String(data: request.httpBody!, encoding: .utf8)!
        BDashLogger.debug("webview request body: \(request_body)")
        
        if self.getWebReceptionStatus != .callingApi {
            BDashLogger.debug("no action")
            return ""
        }
        
        // HTML文字列とURL文字列を取得して返す
        return await withCheckedContinuation { continuation in
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .useProtocolCachePolicy
            self.webViewSession = URLSession(configuration: config)

            self.webViewSession?.dataTask(with: request) { data, response, error in
                if let response = response as? HTTPURLResponse,
                   response.statusCode == 200,
                   error == nil,
                   let data = data
                {
                    Task { @MainActor in
                        guard let htmlString = String(data: data, encoding:BDashWebReception.encoding(response.textEncodingName)) else {
                            continuation.resume(returning: "")
                            return
                        }
                        BDashLogger.debug("URLSession dataTask success")
                        continuation.resume(returning: htmlString)
                    }
                    // HTML文字列の取得が終わったらgetWebReceptionStatusを初期状態に戻す
                    self.getWebReceptionStatus = .initial
                } else {
                    Task { @MainActor in
                        BDashLogger.debug("webViewSession dataTask error \(String(describing: error))")
                    }
                    Task {
                        await self.webViewRequestFailureProcessInEmbedding()
                        continuation.resume(returning: "")
                    }
                }
            }.resume()
        }
    }

    /// キューの先頭から一つタスクを取り出し処理します
    fileprivate func runShowMessageQueueTask() async {
        BDashLogger.debug("[showMessage Queue] runShowMessageQueueTask statusがinitial以外は何もしない")
        BDashLogger.debug("status: \(self.popupStatus)")
        if self.popupStatus == .initial {
            self.popupStatus = .callingApi
            // Queueの先頭から一つ取り出しdeep copy
            if let task = self.dequeue(type: .showMessage) as? ShowMsgObj {
                self.currentTask = task
                BDashLogger.debug("[showMessage Queue] status更新: \(self.popupStatus)")
                let reportDic = await task.report.convertToDic(isSaveToUserDefaults: false)
                let block: () async -> URLSessionDataTask? = { [unowned self] in
                        return await self.update(accessType: .update,
                                                 json: reportDic,
                                                 success: {
                            [weak self] (setting) in
                            Task { @MainActor in
                                BDashLogger.debug("[showMessage Queue] 顧客設定API 成功")
                            }
                            self?.mCsrp = setting
                            // allowClick が確定したので SwiftUI ラッパーへ払い出す（PopupView.init と同じ coercion で挙動を一致させる）
                            self?.onPopupAllowClickResolved?(Bool(setting.allowClick) ?? true)
                            self?.forceShow = setting.forceShow ?? false

                            // UI操作のためメインスレッドで実行
                            Task { @MainActor in
                                var safeArea = UIEdgeInsets()
                                if BDashConstStruct.isReactNative {
                                    safeArea = self?.extractSafeAreaInset() ?? UIEdgeInsets()
                                } else {
                                    safeArea = UIEdgeInsets(top: 20.0, left: 0.0, bottom: 0.0, right: 0.0)
                                    if #available(iOS 11.0, *) {
                                        safeArea = task.view.safeAreaInsets
                                    }
                                }
                                self?.mTmpSafeArea = safeArea
                                var webViewUrl = task.baseUrl + setting.url
                                #if DEBUG
                                if setting.url.hasPrefix("http") {
                                    BDashLogger.debug("[showMessage Queue] jsonファイル内urlはhttp://から始まるのでbase urlを上書きする")
                                    webViewUrl = setting.url
                                }
                                #endif
                                let popupView = PopupView(sizeInfo: setting, safeArea: safeArea, url: webViewUrl, msgObj: task)
                                popupView.delegate = self
                                if let webView = popupView.webView {
                                    webView.navigationDelegate = self
                                }
                                popupView.alpha = 0.0
                                if BDashConstStruct.isReactNative {
                                    if let vc = UIApplication.BDashTopViewController() {
                                        vc.view.addSubview(popupView)
                                    } else {
                                        task.view.addSubview(popupView)
                                    }
                                } else {
                                    task.view.addSubview(popupView)
                                }
                                
                                popupView.moveView(isMoveOut: true)
                                self?.popupView = popupView
                            }
                            
                        }, failure: { [weak self] (err) in
                            // キューを全て破棄
                            Task {
                                await self?.updateFailureProcess()
                            }
                        }
                        )
                }
                
                #if DEBUG
                let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
                if let isWait = ud?.value(forKey: waitSwitchKey) as? Bool, isWait == true {
                    BDashLogger.debug("[showMessage Queue] 顧客設定API call前に7sec wait start........")
                    if #available(iOS 16.0, *) {
                        try? await Task.sleep(for: .seconds(7))
                    } else {
                        // Fallback on earlier versions
                    }
                    Task { @MainActor in
                        BDashLogger.debug("[showMessage Queue] wait end")
                    }
                    self.updateConnectionTask = await block()
                } else {
                    self.updateConnectionTask = await block()
                }
                #else
                Task {
                    self.updateConnectionTask = await block()
                }
                #endif
                
            } else {
                // 実行すべきタスクがQueueにもうない
                BDashLogger.debug("[showMessage Queue] queueが空です")
                self.popupStatus = .initial
                BDashLogger.debug("[showMessage Queue] status更新: \(self.popupStatus)")
            }
        }
    }
    
    fileprivate func runReportQueueTask() async {
        BDashLogger.debug("[report Queue] statusがinitial以外は何もしない")
        if self.reportStatus == .notCalling {
            self.reportStatus = .calling
            if let obj = self.dequeue(type: .report) as? ReportObj {
                self.currentReport = obj
                _ = await self.update(accessType: .tracking, json: obj.report.convertToDic(isSaveToUserDefaults: false),
                        success: { [weak self] (param) in
                            Task { @MainActor in
                                BDashLogger.debug("[report Queue] ==OK== report ====================end====================")
                            }
                            self?.reportStatus = .notCalling
                            Task {
                                await self?.runReportQueueTask()
                            }
                    }, failure: { [weak self] (err) in
                        Task { @MainActor in
                            BDashLogger.debug("[report Queue] ==NG== report ====================end====================")
                        }
                        self?.reportStatus = .notCalling
                        Task {
                            await self?.runReportQueueTask()
                        }
                })
            } else {
                // 実行すべきreportがQueueにもうない
                BDashLogger.debug("[report Queue] queueが空です")
                self.reportStatus = .notCalling
                BDashLogger.debug("[report Queue] status更新: \(self.reportStatus)")
            }
        }
    }
    
    /// 排他制御
    fileprivate func synchronized(_ lock: AnyObject, proc: () -> ()) {
        objc_sync_enter(lock)
        proc()
        objc_sync_exit(lock)
    }
    
    // showMessageにてJavaScript実行します
    fileprivate func runJavascript(jsName: String, completion: (@Sendable (Any?, Error?) -> Void)?) {
        
        DispatchQueue.main.async {
            if let webView = self.popupView?.webView {
                BDashLogger.debug("[showMessage Queue] wkwebview javascript start")
                webView.evaluateJavaScript(jsName, completionHandler: completion)
            } else {
                completion?(nil, nil)
            }
        }
    }
    
    // getWebReceptionにてJavaScript実行します
    fileprivate func runJavascriptInEmbedding(jsName: String, webView: WKWebView?,completion: (@Sendable (Any?, Error?) -> Void)?) {
        DispatchQueue.main.async {
            let confirmGetWebReceptionView = webView
            if let webReceptionView = confirmGetWebReceptionView {
                BDashLogger.debug("[getWebReception Queue] wkwebview javascript start")
                webReceptionView.evaluateJavaScript(jsName, completionHandler: completion)
            } else {
                completion?(nil, nil)
            }
        }
    }
    
    fileprivate func updateFailureProcess() async {
        BDashLogger.debug("[showMessage Queue] ==ERROR== 顧客設定 API失敗")
        await self.clearQueue()
        self.popupStatus = .initial
        BDashLogger.debug("[showMessage Queue] status更新: \(self.popupStatus)")
    }

    // 顧客設定APIは成功したが配信対象が0件だった場合の正常終了処理
    fileprivate func updateNoReceptionProcess() async {
        BDashLogger.debug("[showMessage Queue] 配信対象なし")
        await self.clearQueue()
        self.popupStatus = .initial
        BDashLogger.debug("[showMessage Queue] status更新: \(self.popupStatus)")
    }

    // 埋め込みWEB接客の顧客設定APIが失敗した場合
    fileprivate func embeddingFailureProcess() async {
        BDashLogger.debug("[getWebReception Queue] ==ERROR== 顧客設定 API失敗")
        self.getWebReceptionClearQueue()
        self.getWebReceptionStatus = .initial

        BDashLogger.debug("[getWebReception Queue] status更新: \(self.getWebReceptionStatus)")
    }

    // 埋め込みWEB接客の顧客設定APIは成功したが配信対象が0件だった場合の正常終了処理
    fileprivate func embeddingNoReceptionProcess() async {
        BDashLogger.debug("[getWebReception Queue] 配信対象なし")
        self.getWebReceptionClearQueue()
        self.getWebReceptionStatus = .initial

        BDashLogger.debug("[getWebReception Queue] status更新: \(self.getWebReceptionStatus)")
    }
    
    /// WebView失敗、java script未定義、showMessage、status code != 200の場合コールされる
    @MainActor
    fileprivate func webViewRequestFailureProcess() async {
        BDashLogger.debug("[showMessage Queue] ==ERROR== WebView Request API失敗")
        // webViewがnilかどうかで再表示できるかどうか決まるため、失敗時はnilをセットする
        self.popupView?.webView = nil
        BDashLogger.debug("===============")
        BDashLogger.debug("\(self.extractSubviewCount() as Any)")
        BDashLogger.debug("===============")
        self.popupView?.removeFromSuperview()
        self.popupStatus = .initial
    
        BDashLogger.debug("[showMessage Queue] status更新: \(self.popupStatus)")
        BDashLogger.debug("[showMessage Queue] QueueにtaskがあればRetry")
        await self.runShowMessageQueueTask()
    }
    
    /// WebView失敗、java script未定義、getWebReception、status code != 200の場合コールされる
    @MainActor
    func webViewRequestFailureProcessInEmbedding() async {
        BDashLogger.debug("[getWebReception Queue] ==ERROR== WebView Request API失敗")
        // getWebReceptionStatusをinitialに戻す
        self.getWebReceptionStatus = .initial
    
        BDashLogger.debug("[getWebReception Queue] status更新: \(self.getWebReceptionStatus)")
    }
    
    // 使用端末のセーフエリアを抽出して返却
    @MainActor fileprivate func extractSafeAreaInset() -> UIEdgeInsets {
        // iOS11.0未満の端末のセーフエリア規定値で初期化
        var safeArea = UIEdgeInsets(top: 20.0, left: 0.0, bottom: 0.0, right: 0.0)
        if #available(iOS 11.0, *) {
            if let vc = UIApplication.BDashTopViewController() {
                safeArea = vc.view.safeAreaInsets
            }
        }
        return safeArea
    }
    
    //MARK: - API
    fileprivate func post(urlString: String, json: Data?, success: @Sendable @escaping (Any) -> (), failure: @Sendable @escaping (Error?) -> ()) -> URLSessionDataTask? {
        guard let json = json else { return nil }
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = json
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error == nil {
                    if let res = response as? HTTPURLResponse, let data = data {
                        if res.statusCode == 200 {
                            Task { @MainActor in
                                BDashLogger.debug("[showMessage Queue] status code:\(res.statusCode)")
                            }
                            // メインスレッドでsuccessクロージャを実行
                            success(data)
                        } else {
                            Task { @MainActor in
                                BDashLogger.debug("[showMessage Queue] status code:\(res.statusCode)")
                            }
                            failure(nil)
                        }
                    }
                } else {
                    failure(error)
                }
            }
            // 送信タスク実行
            task.resume()
            return task
        } else {
            failure(nil)
            return nil
        }
    }
    
    fileprivate func convertToJsonAndUrlEncode(dic: [AnyHashable: Any]) -> String {
        var encodedJson: String = ""
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
            if let jsonString = String(bytes: jsonData, encoding: .utf8) {
                encodedJson = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                
            }
        } catch {
            BDashLogger.debug("[showMessage Queue] error")
        }
        
        return encodedJson
    }
    
    /// スキーマにより処理を分岐させる処理です
    /// showMessage使用時に動作
    /// - Parameter url: 読み込むURL
    fileprivate func performCommonLoadProcessEachScheme(url: URL?) async -> Bool {
        guard let url = url else { return false }
        guard let scheme = url.scheme else { return false }
        
        switch scheme {
        case "external":
            // 外部ブラウザを起動（http/httpsスキームのみ許可）
            if let urlParam = self.getUrlParameter(url: url.absoluteString),
               let url = URL(string: addColonToUrlIfNeeded(url: urlParam)),
               url.scheme == "https" || url.scheme == "http" {
                Task {
                    if #available(iOS 10.0, *) {
                        await UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        // Fallback on earlier versions
                        await UIApplication.shared.openURL(url)
                    }
                }
            }
            await self.closeMessage()
        case "internal":
            let param = suffixUrl(url, count: 11)
            self.eventDelegate?(eventType.EVENT_INTERNAL.rawValue, self.decodeAndSplitParameter(encoded: param))
            await self.closeMessage()
        case "webview":
            let param = suffixUrl(url, count: 14)
            if let urlParam = URL(string: addColonToUrlIfNeeded(url: param)) {
                var res: [AnyHashable: Any] = [:]
                res["url"] = "\(urlParam)"
                self.eventDelegate?(eventType.EVENT_WEBVIEW.rawValue, res)
                await self.closeMessage()
            }
        case "popup":
            if let urlParam = self.getUrlParameter(url: url.absoluteString),
                let url = URL(string: addColonToUrlIfNeeded(url: urlParam)) {
                // javascript: / file: などの危険なスキームを弾くため http / https のみ許可する
                if isAllowedHttpUrl(url: url) {
                    Task {
                        await self.popupView?.webView?.load(URLRequest(url: url))
                    }
                } else {
                    BDashLogger.warning(">> popup: 許可されていないスキームのため読み込みません: \(url.absoluteString)")
                }
            }
            return true
        case "command":
            if let urlParam = self.getUrlParameter(url: url.absoluteString) {
                let paths = urlParam.components(separatedBy: "/")
                guard let command = commandType(rawValue: paths[0]) else { return false }
                switch command {
                case .close:
                    await self.closeMessage()
                case .copy:
                    let copyContent = paths[1...].joined(separator: "/")
                    self.copyMessage(copyStr: copyContent)
                }
            }
        case "http", "https":
            return true
        default:
            BDashLogger.debug("\(url)")
        }
        return false
    }
    
    /// 埋め込みWEB接客のスキーマにより処理を分岐させる処理
    /// - Parameter url: 読み込むURL
    public func performEachSchemeInEmbedding(url: URL?) async -> Bool {
        guard let url = url else { return false }
        guard let scheme = url.scheme else { return false }
        
        switch scheme {
        case "external":
            // 外部ブラウザを起動（http/httpsスキームのみ許可）
            if let urlParam = self.getUrlParameter(url: url.absoluteString),
               let url = URL(string: addColonToUrlIfNeeded(url: urlParam)),
               url.scheme == "https" || url.scheme == "http" {
                Task {
                    if #available(iOS 10.0, *) {
                        await UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        // Fallback on earlier versions
                        await UIApplication.shared.openURL(url)
                    }
                }
            }
        case "internal":
            let param = suffixUrl(url, count: 11)
            self.getWebReceptionEventDelegate?(eventType.EVENT_INTERNAL.rawValue, self.decodeAndSplitParameter(encoded: param))
        case "webview":
            let param = suffixUrl(url, count: 14)
            if let urlParam = URL(string: addColonToUrlIfNeeded(url: param)) {
                var res: [AnyHashable: Any] = [:]
                res["url"] = "\(urlParam)"
                self.getWebReceptionEventDelegate?(eventType.EVENT_WEBVIEW.rawValue, res)
            }
        case "http", "https":
            return true
        default:
            BDashLogger.debug("\(url)")
        }
        return false
    }
    
    /// html読み込み後にstatus codeとjavascript実行により表示判定をします
    /// 埋め込みWEB接客で使用
    /// - Parameter statusCode: web view requestの結果のhttp status code
    public func performFinishProcessInEmbedding(statusCode: Int, webView: WKWebView) async {
        if statusCode == 200 {
            let confirmGetWebReceptionView = webView
            self.runJavascriptInEmbedding(jsName: BDashConstStruct.javaScriptSuccessWebView, webView: confirmGetWebReceptionView) { (res, err) in
                    // java script成功
                    if let res = res as? String, res == "0" {
                        // successWebview()が成功
                        Task { @MainActor in
                            BDashLogger.debug("[getWebReception Queue] ==OK== javascript(\(BDashConstStruct.javaScriptSuccessWebView)) OK")
                        }
                        
                        // getWebReceptionStatusをinitialに戻す
                        self.getWebReceptionStatus = .initial
                    } else {
                        // java script失敗
                        Task { @MainActor in
                            BDashLogger.debug("[getWebReception Queue] ==ERROR== javascript(\(BDashConstStruct.javaScriptSuccessWebView)) NG")
                        }
                        Task {
                            await self.webViewRequestFailureProcessInEmbedding()
                        }
                    }
                }
        } else {
            BDashLogger.debug("[getWebReception Queue] ==ERROR== :status code \(statusCode)")
            Task {
                await self.webViewRequestFailureProcessInEmbedding()
            }
        }
    }
    
    fileprivate func suffixUrl(_ url: URL, count: Int) -> String {
        let urlString = url.absoluteString
        return String(urlString.suffix(urlString.count-count))
    }
    
    /// scheme以降にあるURL文字列を取得します
    ///
    /// - Parameter url: url
    /// - Returns: scheme以降の文字(internal://aiueo、というものであれば最初のコロンから三文字分先にインデックスを進め、そこから最後までを返します)
    fileprivate func getUrlParameter(url: String) -> String? {
        if let index = url.firstIndex(of: ":") {
            let addedIndex = url.index(index, offsetBy: 3)
            /// Swift5.0 より前の場合
//            return url.substring(addedIndex.encodedOffset...)
            /// Swift5.0 以降の場合
            return url.substring(addedIndex.utf16Offset(in: url)...)
        }
        return nil
    }
    
    /// linkから取得したURLがなぜかコロンが落とされているのでここでつける
    fileprivate func addColonToUrlIfNeeded(url: String) -> String {
        let tmpUrl = url
        if url.range(of: "https:") != nil || url.range(of: "http:") != nil {
            // もしhttps:,http:があれば特に何もしなくてよいのでそのまま返す
            return url
        } else if let range = url.range(of: "https//") {
            let res = tmpUrl.replacingCharacters(in: range, with: "https://")
            BDashLogger.debug("urlをリプレースしました before:\(url) after:\(res)")
            return res
        } else if let range = url.range(of: "http//") {
            let res = tmpUrl.replacingCharacters(in: range, with: "http://")
            BDashLogger.debug("urlをリプレースしました before:\(url) after:\(res)")
            return res
        } else {
            return url
        }
    }

    /// popupスキームで読み込むURLが http / https のみであることを検証します
    /// (Android の isAllowedHttpUrl 相当。javascript: / file: などの危険なスキームを弾く)
    fileprivate func isAllowedHttpUrl(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    fileprivate func decodeAndSplitParameter(encoded: String) -> [AnyHashable: Any] {
        var res: [AnyHashable: Any] = [:]
        let encodedParams = encoded.components(separatedBy: "&")
        for encodedParam in encodedParams {
            let keyAndEncodedValue = encodedParam.components(separatedBy: "=")
            if keyAndEncodedValue.count > 1 {
                if let decodedValue = keyAndEncodedValue[1].removingPercentEncoding {
                    res[keyAndEncodedValue[0]] = self.addColonToUrlIfNeeded(url: decodedValue)
                }
            } else if keyAndEncodedValue.count == 1 {
                res[keyAndEncodedValue[0]] = ""
            }
        }
        return res
    }
    
    /// html読み込み後にstatus codeとjavascript実行により表示判定をし、ポップアップを表示します
    ///
    /// - Parameter statusCode: web view requestの結果のhttp status code
    fileprivate func performCommonDidFinishProcess(statusCode: Int) async {
        if statusCode == 200 {
            let successBlock: @Sendable () async -> () = {
                Task { @MainActor in
                    BDashLogger.debug("start show animation")
                }

                Task {
                    await self.popupView?.moveView(isMoveOut: false)
                    await self.popupView?.startAnimation()
                }
                self.popupStatus = .showing
                Task { @MainActor in
                    BDashLogger.debug("[showMessage Queue] status更新: \(self.popupStatus)")
                }
                
                // キューを全て破棄
                await self.clearQueue()
            }
            
            if self.forceShow == true {
                BDashLogger.debug("[showMessage Queue] forceShow: true")
                await successBlock()
            } else {
                BDashLogger.debug("[showMessage Queue] forceShow: false")
                runJavascript(jsName: BDashConstStruct.javaScriptSuccessWebView) { [weak self] (res, err) in
                    // java script成功でポップアップを出す
                    if let res = res as? String, res == "0" {
                        Task { @MainActor in
                            BDashLogger.debug("[showMessage Queue] ==OK== javascript(\(BDashConstStruct.javaScriptSuccessWebView)) OK")
                        }
                        
                        Task{
                            await successBlock()
                        }
                    } else {
                        Task { @MainActor in
                            BDashLogger.debug("[showMessage Queue] ==ERROR== javascript(\(BDashConstStruct.javaScriptSuccessWebView)) NG")
                        }
                        Task {
                            await self?.webViewRequestFailureProcess()
                        }
                    }
                }
            }
            
        } else {
            BDashLogger.debug("[showMessage Queue] ==ERROR== :status code \(statusCode)")
            await self.webViewRequestFailureProcess()
        }
    }

    @MainActor
    fileprivate func extractSubviewCount() -> Int {
            let count: Int = self.currentTask?.view.subviews.count ?? 0
            if BDashConstStruct.isReactNative {
                // ポップを表示中か
                if self.popupStatus.rawValue < popupStatusType.showing.rawValue {
                    return count + 1 // ポップアップ分を追加
                } else {
                    return count
                }
            } else {
                return count
            }
    }
    
    public func setUrlParameter(baseUrls: [String], jsonNames: [String]) {
        #if DEBUG
        self.overwrittenBaseUrls = baseUrls
        self.overwrittenJsonFiles = jsonNames
        #endif
    }
    
    /**
     アラート表示
     - parameter title: アラートタイトル
     - parameter body: アラート本文
     - parameter image: アラート画像
     - parameter playSound: trueなら音とバイブレートを鳴らす
     - returns:なし
     */
    func showAlert(title: String?, body: String?) {
        DispatchQueue.main.async    {
            let alert: UIViewController = {
                let alert = UIAlertController(title:title, message: body, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "閉じる", style: .default, handler: nil))
                return alert
            }()

            var baseView:UIViewController = (UIApplication.shared.windows.first { $0.isKeyWindow }!.rootViewController)!

            while(baseView.presentedViewController != nil &&
                !(baseView.presentedViewController?.isBeingDismissed)!) {
                    baseView = baseView.presentedViewController!;
            }
            baseView.present(alert, animated: true, completion: nil)

        }
    }
    
    public func setUrlParameterForReporter(baseUrls: [String], jsonNames: [String]) {
        #if DEBUG
        BDashWebReception.reporter.overwrittenBaseUrls = baseUrls
        BDashWebReception.reporter.overwrittenJsonFiles = jsonNames
        #endif
    }

    // isDebug report wait
    public func setWaitParameter(url: String, jsonName: String) {
        #if DEBUG
        self.setUrlParameterForReporter(baseUrls: [url], jsonNames: [jsonName])
        #endif
    }
    
    class func encoding(_ textEncodingName: String?) -> String.Encoding {
        // 大小文字を無視して比較
        if textEncodingName?.caseInsensitiveCompare("UTF-8") == .orderedSame {
            return .utf8
        } else if textEncodingName?.caseInsensitiveCompare("shift_jis") == .orderedSame {
            return .shiftJIS
        } else if textEncodingName?.caseInsensitiveCompare("euc-jp") == .orderedSame {
            return .japaneseEUC
        } else {
            return .utf8
        }
    }
}

//MARK: WKNavigationDelegate
extension BDashWebReception: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        // タップされたリンクURL(navigationAction.request.url)からスキームを判定する。
        // webView.urlはコミット後のURLであり独自スキームでは不安定なため使用しない。
        let requestUrl = navigationAction.request.url
        self.scheme = requestUrl?.scheme
        BDashLogger.debug("scheme:\(String(describing: self.scheme))")

        switch self.scheme {
        case "internal", "webview", "popup", "external", "command":
            // 独自スキームは元のナビゲーションをキャンセルし、ここでスキーム処理を行う
            // (Androidの shouldOverrideUrlLoading + return true 相当)
            decisionHandler(.cancel)
            Task {
                _ = await self.performCommonLoadProcessEachScheme(url: requestUrl)
            }
        default:
            // http/https やポップアップ初期表示の通常読み込みはそのまま許可する
            decisionHandler(.allow)
        }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // スキーム処理は decidePolicyFor で実施するためここでは何もしない
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {

        guard let httpURLResponse = navigationResponse.response as? HTTPURLResponse else { return }
        self.statusCode = httpURLResponse.statusCode
        
        if self.statusCode == 200 {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if self.popupStatus.rawValue < popupStatusType.showing.rawValue {
            // java scriptを実行して成功したらPopupを表示
            Task {
                await self.performCommonDidFinishProcess(statusCode: self.statusCode)
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        if self.scheme == "http" || self.scheme == "https" {
            Task {
                await webViewRequestFailureProcess()
            }
        } else {
            BDashLogger.debug("schemeがhttp以外だと無条件でエラー処理に来るが、エラー処理はしない\(String(describing: self.scheme))")
        }
    }
}

//MARK: PopupViewDelegate

extension BDashWebReception: PopupViewDelegate {
    func notifyPopupClosed() {
        self.runJavascript(jsName: BDashConstStruct.javaScriptOnClose) { (res, err) in
            Task { @MainActor in
                BDashLogger.debug("[showMessage Queue] javascript finished")
            }
            Task {
                await self.closeMessage()
            }
        }
    }
    
    /// WebView リクエストAPIをコールします
    ///
    /// - Parameters:
    ///   - webView: htmlを読み込むWKWebView
    ///   - url: 読み込むURL
    ///   - msgObj: showMessage情報
    @MainActor
    func getWebView(webView: WKWebView?, url: String, msgObj: ShowMsgObj) async {
        guard let url = URL(string: url) else { return }
        BDashLogger.debug("[showMessage Queue] web view APIをコールします。 url:\(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = BDashConst.kRequestPerLimitTime

        let commonPara = await self.getCommonParameter()
        let reportDic = await msgObj.report.convertToDic(isSaveToUserDefaults: false)
        
        let keyList = ["uuId", "trigger", "view", "preView", "page", "prePage", "eventFunc", "customProperty"]
        var param: [AnyHashable: Any] = [:]
        
        for key in keyList {
            if key == "uuId" {
                // commomParameterのキーはuuIdだがapiの仕様ではuuidでキーを送るようになっていることに注意
                param["uuid"] = commonPara["uuId"] as? String ?? ""
            } else {
                param[key] = reportDic[key]
            }
        }
        let paramStr = convertToJsonAndUrlEncode(dic: param)
        request.httpBody = paramStr.data(using: .utf8)
        // リクエストのBodyをログ出力する
        let request_body: String = String(data:request.httpBody!, encoding:String.Encoding.utf8)!
        BDashLogger.debug("webview request body: \(request_body)")
        
        if self.popupStatus != .callingApi {
            // APIコール中にcloseMessageが呼ばれた場合
            BDashLogger.debug("no action")
            return
        }

        if #available(iOS 11.0, *) {
            webView?.load(request)
        } else {
            // ユーザーエージェントの取得
            webView?.evaluateJavaScript("navigator.userAgent") { (userAgent, error) in
                if let userAgent = userAgent as? String,
                   error == nil {
                    BDashLogger.debug("User-Agent: \(userAgent)")
                    // ユーザーエージェントの設定
                    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                } else {
                    BDashLogger.debug("User-Agent: nil or error")
                }
                
                let config = URLSessionConfiguration.default
                // iOS11未満では、ローカルキャッシュを無視
                config.requestCachePolicy = .reloadIgnoringLocalCacheData
                self.webViewSession = URLSession(configuration: config)
                
                self.webViewSession?.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
                    if let response = response as? HTTPURLResponse,
                       response.statusCode == 200,
                       error == nil,
                       let data = data,
                       let htmlString = String(data: data, encoding: BDashWebReception.encoding(response.textEncodingName)) {
                        Task { @MainActor in
                            BDashLogger.debug("webViewSession dataTask success")
                            webView?.loadHTMLString(htmlString, baseURL: url)
                        }
                    } else {
                        Task { @MainActor in
                            BDashLogger.debug("webViewSession dataTask error \(String(describing: error))")
                        }
                        Task {
                            await self.webViewRequestFailureProcess()
                        }
                    }
                }).resume()
            }
        }
    }
}

//MARK: - PopupView Class

protocol PopupViewDelegate: AnyObject, Sendable {
    func notifyPopupClosed()
    func getWebView(webView: WKWebView?, url: String, msgObj: ShowMsgObj) async
}

enum deviceOrientation: Int {
    case normal = 1
    case upsideDown
    case left
    case right
}

fileprivate class PopupView: TransmissionView {
    
    weak var delegate: PopupViewDelegate?
    var effect: String = ""
    var effectDuration: Double = 2.0
    //    var allowClick: Bool = true
    //    var useFilter: Bool = false
    static var buttonSize: CGSize = CGSize(width: 33.0, height: 33.0)
    
    // web viewと閉じるボタンの親View
    let backgroundView: TransmissionView = {
        let view = TransmissionView()
        view.backgroundColor = .clear
        return view
    }()
    
    var webView: WKWebView?
    
    // 閉じるボタン
    lazy var closeButton: UIButton = {
        let view = UIButton()
        view.setBackgroundImage(UIImage(named: "jp_co_f-scratch_closebutton.png"), for: .normal)
        view.frame = CGRect(x: 0.0, y: 0.0, width: PopupView.buttonSize.width, height: PopupView.buttonSize.height)
        view.addTarget(self, action: #selector(touchUpInsideCloseButton), for: .touchUpInside)
        return view
    }()
    
    // 閉じるボタンがポップアップ外に配置されていても動作するようにする
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // 子ビューにタッチイベントを渡す
    // ボタンの座標系にポイントを変換
        let convertedPoint = closeButton.convert(point, from: self)
        if closeButton.bounds.contains(convertedPoint) {
            // ボタンがタッチ領域に含まれている場合、そのボタンを返す
            return closeButton
        }
        // 通常のタッチ処理を実行
        return super.hitTest(point, with: event)
    }
    
    private var csrp: CustomerSettingResponseParam?
    
    // webViewの表示設定
    init(sizeInfo: CustomerSettingResponseParam, safeArea: UIEdgeInsets, url: String, msgObj: ShowMsgObj) {
        super.init(frame: UIScreen.main.bounds, allowClick:  Bool(sizeInfo.allowClick) ?? true)
        
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.csrp = sizeInfo
        
        self.effect = sizeInfo.effect
        self.effectDuration = sizeInfo.effectDuration
        if Bool(sizeInfo.useFilter) ?? false == true {
            // 画面を暗くするか
            self.backgroundColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.5)
        } else {
            self.backgroundColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.0)
        }
        
        self.addSubview(backgroundView)
        
        let webView = WKWebView()
        self.webView = webView
        backgroundView.addSubview(webView)
        
        // 閉じるボタンの画像をURLから設定する。
        // closeButton は生成時にデフォルト画像が設定済みのため、取得失敗・非対応形式・URL不正のいずれの場合も
        // 上書きされずデフォルト画像のまま表示される。
        let closeButtonURLString = sizeInfo.closeButtonSrc

        if (closeButtonURLString.hasSuffix(".png")) {
            if let closeButtonURL = URL(string: closeButtonURLString) {
                downloadImage(from: closeButtonURL) { [weak self] image in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if let image = image {
                            self.closeButton.setBackgroundImage(image, for: .normal)
                        } else {
                            // 画像の取得に失敗した場合、デフォルトの閉じるボタン画像（生成時に設定済み）をそのまま使用する
                            BDashLogger.debug("画像のダウンロードに失敗したためデフォルトの閉じるボタンを使用します")
                        }
                    }
                }
            }
        } else {
            // svg等、サポートしていない形式の閉じるボタン画像が来た場合、デフォルトの閉じるボタン画像をそのまま使用する
            BDashLogger.debug("サポートされていない形式なのでデフォルトの閉じるボタンを表示します: \(closeButtonURLString)")
        }
        backgroundView.addSubview(closeButton)
        // レスポンスデータからポップアップ表示ビューを生成
        self.setPopupPartsFrame(sizeInfo: sizeInfo, safeArea: safeArea)
        // Web接客・WebViewリクエストAPIを呼出
        #if DEBUG
        let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
        if let isWait = ud?.value(forKey: waitSwitchKey) as? Bool, isWait == true {
            BDashLogger.debug("[showMessage Queue] Web View API call前に7sec wait start........")
            DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                BDashLogger.debug("[showMessage Queue] wait end")
                Task {
                    await self.delegate?.getWebView(webView: self.webView, url: url, msgObj: msgObj)
                }
            }
        } else {
            Task {
                await self.delegate?.getWebView(webView: self.webView, url: url, msgObj: msgObj)
            }
        }
        #else
        Task {
            await self.delegate?.getWebView(webView: self.webView, url: url, msgObj: msgObj)
        }
        #endif
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor
    deinit {
        Task { @MainActor in
            BDashLogger.debug("PopupView deinit")
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let csrp = csrp else {
            return
        }
        
        let safeArea = self.safeAreaInsets
        
        self.setPopupPartsFrame(sizeInfo: csrp, safeArea: safeArea)
    }
    
    // 非同期で画像をダウンロードするメソッド
    private func downloadImage(from url: URL, completion: @Sendable @escaping (UIImage?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let data = data,
                error == nil,
                let image = UIImage(data: data)
            else {
                Task { @MainActor in
                    BDashLogger.debug("Failed to load image from URL: \(url)")
                }
                completion(nil)
                return
            }
            completion(image)
        }
        task.resume()
    }
    
    /// 回転することを考慮して、生成のタイミングで縦横それぞれの場合のframeを計算します
    fileprivate func setPopupPartsFrame(sizeInfo: CustomerSettingResponseParam, safeArea: UIEdgeInsets) {
        
        let width = self.bounds.width
        let height = self.bounds.height
        
        // 画面サイズからmarginを引いた値に対してwidth(%)が決定することに注意
        let widthOfScreenWithinSafeArea: CGFloat = width - safeArea.left - safeArea.right
        let heightOfScreenWithinSafeArea: CGFloat = height - safeArea.top - safeArea.bottom
        
        // 閉じるボタンを含む、ポップアップ全体のviewのサイズを計算
        var widthWithinScreen: CGFloat = 0
        var heightWithinScreen: CGFloat = 0
        
        if (sizeUnitSetting == "px") {
            widthWithinScreen = min(sizeInfo.widthPx, widthOfScreenWithinSafeArea)
            heightWithinScreen = sizeInfo.heightPx
        } else {
            widthWithinScreen = sizeInfo.width <= 1.00 ? widthOfScreenWithinSafeArea * sizeInfo.width : widthOfScreenWithinSafeArea
            heightWithinScreen = widthWithinScreen * CGFloat(sizeInfo.height)
        }
        
        // ポップアップ全体の位置を計算
        var xPosition: CGFloat = 0.0
        var yPosition: CGFloat = 0.0
        
        // 上下のセーフエリアを侵食していれば、収まるように縮小する
        if heightWithinScreen > heightOfScreenWithinSafeArea {
            let ratio: CGFloat = heightOfScreenWithinSafeArea / heightWithinScreen
            widthWithinScreen *= ratio
            heightWithinScreen *= ratio
        }
        
        // x方向の位置を計算
        switch sizeInfo.horizontalAlign {
        case LayoutKey.left:
            xPosition = safeArea.left
            if sizeInfo.horizontalMargin > 0 {
                xPosition += CGFloat(sizeInfo.horizontalMargin)
                let rightEdgeOfSafeArea = width - safeArea.right
                let rightEdgeOfPopup = xPosition + widthWithinScreen
                if rightEdgeOfPopup > rightEdgeOfSafeArea {
                    // マージンによって、閉じるボタン含むポップアップの右端が右側のセーフエリアに侵食する場合、右寄せになる
                    xPosition = width - widthWithinScreen - safeArea.right
                }
            }

        case LayoutKey.center:
            let rightMargin = widthOfScreenWithinSafeArea - widthWithinScreen
            let isOverRightSafeArea = rightMargin < (PopupView.buttonSize.width / 2.0) ? true : false
            if isOverRightSafeArea {
                // 中央寄せ時に、閉じるボタンの右端が右側のセーフエリアに侵食する場合、マージン0の右寄せになる
                xPosition = width - widthWithinScreen - safeArea.right
            } else {
                // 閉じるボタンを含む中央寄せ値
                xPosition = safeArea.left + (widthOfScreenWithinSafeArea / 2.0) - (widthWithinScreen / 2.0)
            }

        case LayoutKey.right:
            xPosition = width - widthWithinScreen - safeArea.right
            if sizeInfo.horizontalMargin > 0 {
                xPosition -= CGFloat(sizeInfo.horizontalMargin)
                let leftEdgeOfSafeArea = safeArea.left
                let leftEdgeOfPopup = xPosition
                if leftEdgeOfPopup < leftEdgeOfSafeArea {
                    // マージンによって、ポップアップの左端が左側のセーフエリアに侵食する場合、左寄せになる
                    xPosition = safeArea.left
                }
            }
            
        default:
            // 指定がなければ中央揃え
            let rightMargin = widthOfScreenWithinSafeArea - widthWithinScreen
            let isOverRightSafeArea = rightMargin < (PopupView.buttonSize.width / 2.0) ? true : false
            if isOverRightSafeArea {
                // 中央寄せ時に、閉じるボタンの右端が右側のセーフエリアに侵食する場合、マージン0の右寄せになる
                xPosition = width - widthWithinScreen - safeArea.right
            } else {
                // 閉じるボタンを含む中央寄せ値
                xPosition = safeArea.left + (widthOfScreenWithinSafeArea / 2.0) - (widthWithinScreen / 2.0)
            }
        }
        
        // y方向の位置を計算
        switch sizeInfo.verticalAlign {
        case LayoutKey.top:
            yPosition = safeArea.top
            if sizeInfo.verticalMargin > 0 {
                yPosition += CGFloat(sizeInfo.verticalMargin)
                let bottomEdgeOfSafeArea = height - safeArea.bottom
                let bottomEdgeOfPopup = yPosition + heightWithinScreen
                // マージンによって、ポップアップの下端が下側のセーフエリアに侵食する場合、下寄せになる
                if bottomEdgeOfPopup > bottomEdgeOfSafeArea {
                    yPosition = height - heightWithinScreen - safeArea.bottom
                }
            }
            
        case LayoutKey.center:
            let heightMargin = heightOfScreenWithinSafeArea - heightWithinScreen
            let isOverTopSafeArea = heightMargin < (PopupView.buttonSize.height / 2.0) ? true : false
            if isOverTopSafeArea {
                // 中央寄せ時に、閉じるボタンの上端が上側のセーフエリアに侵食する場合、マージン0の上寄せになる
                yPosition = safeArea.top
            } else {
                yPosition = safeArea.top + (heightOfScreenWithinSafeArea / 2.0) - (heightWithinScreen / 2.0)
                // 閉じるボタンを含まない中央寄せ値にするための値調整
                yPosition -= (PopupView.buttonSize.height * 0.5) * 0.5;
            }
            
        case LayoutKey.bottom:
            yPosition = height - heightWithinScreen - safeArea.bottom
            if sizeInfo.verticalMargin > 0 {
                yPosition -= CGFloat(sizeInfo.verticalMargin)
                let topEdgeOfSafeArea = safeArea.top
                let topEdgeOfPopup = yPosition
                // マージンによって、閉じるボタン含むポップアップの上端が上側のセーフエリアに侵食する場合、上寄せになる
                if topEdgeOfPopup < topEdgeOfSafeArea {
                    yPosition = safeArea.top
                }
            }
        
        default:
            // 指定がなければ中央揃え
            let heightMargin = heightOfScreenWithinSafeArea - heightWithinScreen
            let isOverTopSafeArea = heightMargin < (PopupView.buttonSize.height / 2.0) ? true : false
            if isOverTopSafeArea {
                // 中央寄せ時に、閉じるボタンの上端が上側のセーフエリアに侵食する場合、マージン0の上寄せになる
                yPosition = safeArea.top
            } else {
                yPosition = safeArea.top + (heightOfScreenWithinSafeArea / 2.0) - (heightWithinScreen / 2.0)
                // 閉じるボタンを含まない中央寄せ値にするための値調整
                yPosition -= (PopupView.buttonSize.height * 0.5) * 0.5;
            }
        }
        
        // 閉じるボタンのサイズと位置を設定 ※ closeButtonSrc指定時はカスタムサイズ・座標、未指定時はデフォルト(既存)の処理を行う
        if (!sizeInfo.closeButtonSrc.isEmpty) {
            // 閉じるボタンのサイズを計算
            let closeButtonWidth: CGFloat = widthWithinScreen * sizeInfo.closeButtonWidth
            let closeButtonHeight: CGFloat = closeButtonWidth * sizeInfo.closeButtonHeight
            
            // 閉じるボタンの座標を計算
            let closeButtonXposition: CGFloat = widthWithinScreen * sizeInfo.closeButtonHorizontalAlign
            let closeButtonYposition: CGFloat = heightWithinScreen * sizeInfo.closeButtonVerticalAlign
            
            backgroundView.frame = CGRect(origin: CGPoint(x: xPosition, y: yPosition),
                                          size: CGSize(width: widthWithinScreen, height: heightWithinScreen))

            let webViewFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: widthWithinScreen, height: heightWithinScreen))
            
            webView?.frame = webViewFrame
            webView?.isOpaque = false
            webView?.backgroundColor = UIColor.clear

            // 閉じるボタンのサイズを設定
            PopupView.buttonSize = CGSize(width: closeButtonWidth, height: closeButtonHeight)
            
            // 閉じるボタンの座標位置を設定 (アプリ接客コンテンツの左上基準)
            closeButton.frame = CGRect(origin: CGPoint(x: closeButtonXposition, y: closeButtonYposition),size: PopupView.buttonSize)
        } else {
            
            // 閉じるボタンのサイズを設定
            PopupView.buttonSize = CGSize(width: 33.0, height: 33.0)

            // webViewと閉じるボタンを含めた大枠のサイズを決め、それを元にwebView, 閉じるボタンのサイズを決める
            backgroundView.frame = CGRect(origin: CGPoint(x: xPosition, y: yPosition),
                                          size: CGSize(width: widthWithinScreen, height: heightWithinScreen))
            
            let frameWidth = round(backgroundView.frame.size.width - (PopupView.buttonSize.width / 2.0))
            let frameHight = round(backgroundView.frame.size.height - (PopupView.buttonSize.height / 2.0))
            let webViewFrame = CGRect(origin: CGPoint(x: 0.0, y: PopupView.buttonSize.height / 2.0), size: CGSize(width: frameWidth, height: frameHight))
            webView?.frame = webViewFrame
            webView?.isOpaque = false
            webView?.backgroundColor = UIColor.clear
            
            // 閉じるボタンの座標位置 (左上基準)
            closeButton.frame = CGRect(origin: CGPoint(x: backgroundView.frame.width - PopupView.buttonSize.width, y: 0.0),size: PopupView.buttonSize)
        }
    }
    
    fileprivate func startAnimation() {
        switch self.effect {
        case EffectKey.fadein:
            UIView.animate(withDuration: self.effectDuration) {
                self.alpha = 1.0
            }
        default:
            self.alpha = 1.0
        }
    }
    
    /// 通信成功により表示されるかどうかが決まるので、WKWebViewを画面外へ一時移動させたり戻したりします
    fileprivate func moveView(isMoveOut: Bool) {
        if isMoveOut == true {
            self.frame = CGRect(origin: CGPoint(x: self.bounds.width, y: 0.0),
                                size: self.frame.size)
        } else {
            self.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0),
                                size: self.frame.size)
        }
    }
    
    /// 閉じるボタンの押下を通知
    @objc fileprivate func touchUpInsideCloseButton() {
        delegate?.notifyPopupClosed()
    }
}

//MARK: - TransmissionView Class

/// PopUpViewの背景View（hitTestを利用することでイベントを透過)
fileprivate class TransmissionView: UIView {
    fileprivate var allowClick: Bool?
    
    init(frame: CGRect, allowClick: Bool) {
        self.allowClick = allowClick
        super.init(frame: frame)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if let allow = self.allowClick, allow == true {
            if view == self {
                return nil
            } else {
                return view
            }
        } else {
            return view
        }
    }
    
    // バックグラウンドのframe変更
    fileprivate func changeFrame(frame: CGRect) {
        self.frame = frame
    }
}

//MARK: - BDashWebReceptionController Class
@objcMembers
public final class BDashWebReceptionController: NSObject, Sendable {
    nonisolated(unsafe) fileprivate static var isInitialized: Bool = false
    fileprivate static let shared: BDashWebReceptionController = {
        return BDashWebReceptionController()
    }()
    
    public override init() {
        super.init()
        if BDashWebReceptionController.isInitialized == false {
            BDashWebReceptionController.isInitialized = true
            BDashWebReceptionController.removeTestUserDefaults()
            Task {
                _ = await self.newPopup().update(accessType: .boot, json: [:], success: {_ in }, failure: {_ in })
            }
        }
    }

    private static func removeTestUserDefaults() {
        guard let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults") else { return }
        for key in ["previousInput", "previousFirstHistory", "previousSecondHistory", "waitSwitchKey"] {
            ud.removeObject(forKey: key)
        }
        ud.synchronize()
    }

    public func getInstance() -> BDashWebReceptionController {
        return BDashWebReceptionController.shared
    }
    
    public func newPopup() -> BDashWebReception {
        return BDashWebReception()
    }
}

//MARK: - Extension(CGFloat)

extension CGFloat {
    init?<S>(_ text: S) where S : StringProtocol {
        guard let number = Double(text) else { return nil }
        self.init(number)
    }
}

//MARK: - Extension(String)

extension String {
    
    func substring(_ r: CountableRange<Int>) -> String {
        
        let length = self.count
        let fromIndex = (r.startIndex > 0) ? self.index(self.startIndex, offsetBy: r.startIndex) : self.startIndex
        let toIndex = (length > r.endIndex) ? self.index(self.startIndex, offsetBy: r.endIndex) : self.endIndex
        
        if fromIndex >= self.startIndex && toIndex <= self.endIndex {
            return String(self[fromIndex..<toIndex])
        }
        
        return String(self)
    }
    
    func substring(_ r: CountableClosedRange<Int>) -> String {
        
        let from = r.lowerBound
        let to = r.upperBound
        
        return self.substring(from..<(to+1))
    }
    
    func substring(_ r: CountablePartialRangeFrom<Int>) -> String {
        
        let from = r.lowerBound
        let to = self.count
        
        return self.substring(from..<to)
    }
    
    func substring(_ r: PartialRangeThrough<Int>) -> String {
        
        let from = 0
        let to = r.upperBound
        
        return self.substring(from..<to)
    }
}

//MARK: - Extension(UIApplication)

extension UIApplication {
    // 最前面のViewControllerを取得
    class func BDashTopViewController(controller: UIViewController? = (UIApplication.shared.windows.first { $0.isKeyWindow }!.rootViewController)!) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return BDashTopViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return BDashTopViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return BDashTopViewController(controller: presented)
        }
        return controller
    }
}
