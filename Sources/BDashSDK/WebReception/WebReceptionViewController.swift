import UIKit
import WebKit

// MARK: Swift 6
/**
 テストアプリ用「showMessage Test」画面
 */
class WebReceptionViewController: UIViewController {
       
    @IBOutlet weak var segControl: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var constraintFromBottom: NSLayoutConstraint!
    @IBOutlet weak var defaultValueButton: UIButton!
    @IBOutlet weak var previousValueButton: UIButton!
    @IBOutlet weak var showMessageButton: UIButton!
    @IBOutlet weak var reportButton: UIButton!
    @IBOutlet weak var closeMessageButton: UIButton!
    @IBOutlet weak var historyButton: UIButton!
    @IBOutlet weak var waitBefore2ndSw: UISwitch! // SDK提供APIを呼ぶ前に7秒待つ
    @IBOutlet weak var waitBeforeApiLabel: UILabel!
    @IBOutlet weak var waitBeforeApiSw: UISwitch! // devSwがONの場合に表示される 通信APIが呼ばれる前に7秒待つ
    @IBOutlet weak var devSw: UISwitch!
    
    // 埋め込みWEB接客表示領域
    @IBOutlet weak var confirmGetWebReceptionView: WKWebView!
    // 埋め込みWEB接客表示ボタン
    @IBOutlet weak var getWebReceptionButton: UIButton!
    
    private var historyTableView: UITableView!
    private var inputedBaseUrl: [String] = [BDashConstStruct.baseUrl, BDashConstStruct.baseUrl] // [(1stの初期値), (2ndの初期値)]
    private var inputedJsonFile: [String] = [BDashConstStruct.settingJsonFile, BDashConstStruct.settingJsonFile] // [(1stの初期値), (2ndの初期値)]
    private var reports: [BDashReport] = []
    private var reportWait: [BDashReport] = []
    private var urlWait: [String] = []
    private var jsonFileWait: [String] = []
    private var selectedTestCase: Int = 0
    private var wr: BDashWebReception = BDashWebReceptionController().getInstance().newPopup()

    private let keyOfBaseUrlSetting = "previousBaseUrl"
    private let keyOfJsonFileNameSetting = "previousJsonFileName"
    private let keyOfPreviousSetting = "previousInput"
    private let keyOfFirstHistorySetting = "previousFirstHistory"
    private let keyOfSecondHistorySetting = "previousSecondHistory"
    private let keys: [String] = ["base url", "json file name", "targets", "trigger", "view", "preView", "page", "prePage", "eventFunc", "customProperty"]
    private let triggerPickerList: [String] = ["", "default", "boot", "view", "touch", "scroll"]

    private let defaultPickerList: [String] = ["", "🚑", "①Ⅱⅲ", #""acb\de'"#, "http://おはよう", "PopupScreen","PopupProduct"]
    private var viewPickerList = [String]()
    private var preViewPickerList = [String]()
    private var pagePickerList = [String]()
    private var prePagePickerList = [String]()
    private var eventFuncPickerList = [String]()
    private let customPropertyPickerList: [String] = ["", "__loginUserId", #"__loginUserId=hoge@f-scratch.com"#, #"key1A=value1A,key1B=value1B"#, #"a="acb\de'"#, "a=abc,d=efg,h=ijk", #"a='123\",b='456\n",c=🚑"#, "a"]
    
    // 埋め込みWEB接客で使用
    fileprivate var statusCode: Int = 200
    fileprivate var scheme: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewPickerList = defaultPickerList
        viewPickerList.insert("画面1", at: 1)
        preViewPickerList = defaultPickerList
        preViewPickerList.insert("画面1の前画面", at: 1)
        pagePickerList = defaultPickerList
        pagePickerList.insert("1", at: 1)
        prePagePickerList.append(contentsOf: defaultPickerList)
        prePagePickerList.insert("0", at: 1)
        eventFuncPickerList.append(contentsOf: defaultPickerList)
        eventFuncPickerList.insert("function 1", at: 1)
        
        // table初期設定
        self.tableView.register(UINib.init(nibName: "ReportDataInputCell", bundle: nil), forCellReuseIdentifier: ReportDataInputCell.reuseId)
        // report初期化
        self.reports.append(BDashReport(targets: nil,
                                        trigger: nil,
                                        view: nil,
                                        preView: nil,
                                        page: nil,
                                        prePage: nil,
                                        eventFunc: nil,
                                        customProperty: nil))
        self.reports.append(BDashReport(targets: nil,
                                        trigger: nil,
                                        view: nil,
                                        preView: nil,
                                        page: nil,
                                        prePage: nil,
                                        eventFunc: nil,
                                        customProperty: nil))
        self.prepareViewLayout()
        
        //  キーボードの開閉通知
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.keyboardWillHide),
                                               name:UIResponder.keyboardWillHideNotification,
                                               object: nil)
        
        //7sec wait switch
        self.waitBeforeApiSw.isOn = false
        let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
        if let isWait = ud?.value(forKey: waitSwitchKey) as? Bool {
            if isWait == true {
                self.waitBeforeApiSw.isOn = true
            }
        }
        
        self.valueChangedDevSw(self.devSw)
        
        // 埋め込みWEB接客にて、WKNavigationDelegateを動かすために設定
        confirmGetWebReceptionView.navigationDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Task { @MainActor in
            self.wr.closeMessage()
        }
        self.wr.eventDelegate = nil
    }
    
    deinit {
        BDashLogger.debug("deinit WebReceptionViewController")
    }
    
}

// MARK: - Private

extension WebReceptionViewController {
    
    private func prepareViewLayout() {
        self.defaultValueButton.layer.cornerRadius = 20.0
        self.defaultValueButton.layer.borderColor = self.defaultValueButton.tintColor.cgColor
        self.defaultValueButton.layer.borderWidth = 1.0
        self.previousValueButton.layer.cornerRadius = 20.0
        self.previousValueButton.layer.borderColor = self.previousValueButton.tintColor.cgColor
        self.previousValueButton.layer.borderWidth = 1.0
        self.showMessageButton.layer.cornerRadius = 20.0
        self.showMessageButton.layer.borderColor = self.showMessageButton.tintColor.cgColor
        self.showMessageButton.layer.borderWidth = 1.0
        self.reportButton.layer.cornerRadius = 20.0
        self.reportButton.layer.borderColor = self.reportButton.tintColor.cgColor
        self.reportButton.layer.borderWidth = 1.0
        self.closeMessageButton.layer.cornerRadius = 20.0
        self.closeMessageButton.layer.borderColor = self.closeMessageButton.tintColor.cgColor
        self.closeMessageButton.layer.borderWidth = 1.0
        self.historyButton.layer.cornerRadius = 20.0
        self.historyButton.layer.borderColor = self.closeMessageButton.tintColor.cgColor
        self.historyButton.layer.borderWidth = 1.0
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let userInfo = notification.userInfo, let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            self.constraintFromBottom.constant = keyboardFrame.cgRectValue.height
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        self.constraintFromBottom.constant = 250.0
    }
    
}

// MARK: - 各種IBActionの設定を行う
extension WebReceptionViewController {
    
    /// 1st,2ndスイッチタップ処理
    @IBAction func valueChangedSegControl(_ sender: Any) {
        self.view.endEditing(true)
        tableView.reloadData()
    }
    
    // 埋め込みWEB接客表示ボタンの処理
    @IBAction func touchUpInsideGetWebReceptionButton () {
        Task { @MainActor in
            
            // 入力情報を保持
            var report1 = await self.reports[0].convertToDic(isSaveToUserDefaults: true)
            report1[keyOfBaseUrlSetting] = inputedBaseUrl[0]
            report1[keyOfJsonFileNameSetting] = inputedJsonFile[0]
            
            var report2 = await self.reports[1].convertToDic(isSaveToUserDefaults: true)
            report2[keyOfBaseUrlSetting] = inputedBaseUrl[1]
            report2[keyOfJsonFileNameSetting] = inputedJsonFile[1]
            
            let tmpReports = [report1, report2]
            let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
            ud?.set(tmpReports, forKey: keyOfPreviousSetting)
            ud?.synchronize()
            
            // url取得
            let baseUrl1 = self.inputedBaseUrl[0]
            let baseUrl2 = self.inputedBaseUrl[1]
            let jsonFile1 = self.inputedJsonFile[0]
            let jsonFile2 = self.inputedJsonFile[1]
            
            // base url, json file, urlを上書き
            self.wr.setUrlParameter(baseUrls: [baseUrl1, baseUrl2], jsonNames: [jsonFile1, jsonFile2])
            
            // url,fileNameを保持
            addHistory(key: keyOfFirstHistorySetting, text: baseUrl1 + "," + jsonFile1)
            addHistory(key: keyOfSecondHistorySetting, text: baseUrl2 + "," + jsonFile2)
            
            if let view = self.navigationController?.view {
                // internal, webViewを制御
                self.wr.getWebReceptionEventDelegate = { (type, param) in
                    guard let type = eventType(rawValue: type) else { return }
                    BDashLogger.debug("viewcontroller getWebReception eventDelegate")
                    switch type {
                    case .EVENT_INTERNAL:
                        // MARK: .EVENT_INTERNAL
                        if let view = param["view"] as? String,
                           let date = param["date"] as? String,
                           let url = param["url"] as? String {
                            BDashLogger.debug("\(view)  \(date)  \(url)")
                        }
                        
                        var paramStr = ""
                        for key in param.keys {
                            if let tmpParam = param[key] as? String {
                                if tmpParam.count > 0 {
                                    paramStr = paramStr + "\(key)=\(tmpParam)\n"
                                } else {
                                    paramStr = paramStr + "\(key)\n"
                                }
                            }
                        }
                        paramStr.removeLast()
                        if paramStr == "=" {
                            paramStr = ""
                        }
                        Task {
                            let alert = await UIAlertController(title: "EVENT_INTERNAL",
                                                                message: paramStr,
                                                                preferredStyle: .alert)
                            await alert.addAction(UIAlertAction(title: "OK", style: .default))
                            await self.present(alert, animated: true, completion: nil)
                        }
                        
                    case .EVENT_WEBVIEW:
                        // MARK: .EVENT_WEBVIEW
                        var paramStr = ""
                        if let url = param["url"] as? String {
                            paramStr = "\(url)"
                        }
                        Task {
                            let alert = await UIAlertController(title: "EVENT_WEBVIEW",
                                                                message: paramStr,
                                                                preferredStyle: .alert)
                            await alert.addAction(UIAlertAction(title: "OK", style: .default))
                            await self.present(alert, animated: true, completion: nil)
                        }
                    }
                }
                BDashLogger.debug("===========================current time 1===========================")
                BDashLogger.debug("\(Date().timeIntervalSince1970)")
                BDashLogger.debug("===========================current time 1===========================")
                let htmlString = await self.wr.getWebReception(report: self.reports[0], onView: view)

                // 環境ごとに使用するbaseUrlは変わるので要確認
                let urlString = BDashConstStruct.baseUrl
                BDashLogger.debug("baseURLで使用するURL: \(urlString)")

                guard let url = URL(string: urlString) else { return }
                
                /// getWebReceptionで返ってきたHTML文字列と上の処理で取得したurlを使用して埋め込みWEBViewを表示
                /// ここの処理で当ファイルの下の方にある「extension WebReceptionViewController : WKNavigationDelegate」 が動く

                confirmGetWebReceptionView.loadHTMLString(htmlString, baseURL: url)
            }
            self.getWebReceptionButton.titleLabel?.alpha = 0.0
            UIView.animate(withDuration: 0.2) {
                self.getWebReceptionButton.titleLabel?.alpha = 1.0
            }
        }
    }
    
    /// showMessageタップ処理
    @IBAction func touchUpInsideShowMessageButton(_ sender: Any) {
        Task { @MainActor in
            // 入力情報を保持
            var report1 = await self.reports[0].convertToDic(isSaveToUserDefaults: true)
            report1[keyOfBaseUrlSetting] = inputedBaseUrl[0]
            report1[keyOfJsonFileNameSetting] = inputedJsonFile[0]
            
            var report2 = await self.reports[1].convertToDic(isSaveToUserDefaults: true)
            report2[keyOfBaseUrlSetting] = inputedBaseUrl[1]
            report2[keyOfJsonFileNameSetting] = inputedJsonFile[1]
            
            let tmpReports = [report1, report2]
            let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
            ud?.set(tmpReports, forKey: keyOfPreviousSetting)
            ud?.synchronize()
            
            // url取得
            let baseUrl1 = self.inputedBaseUrl[0]
            let baseUrl2 = self.inputedBaseUrl[1]
            let jsonFile1 = self.inputedJsonFile[0]
            let jsonFile2 = self.inputedJsonFile[1]
            
            // base url, json file, urlを上書き
            self.wr.setUrlParameter(baseUrls: [baseUrl1, baseUrl2], jsonNames: [jsonFile1, jsonFile2])
            
            // url,fileNameを保持
            addHistory(key: keyOfFirstHistorySetting, text: baseUrl1 + "," + jsonFile1)
            addHistory(key: keyOfSecondHistorySetting, text: baseUrl2 + "," + jsonFile2)
            
            // CUSTOM_LOGIN_USERのテスト時は以下のコメントアウトのブロックを外す
            /*
             var customProperty: [String: String] = [BDashReport.CUSTOM_LOGIN_USER:""]
             
             customProperty.updateValue(
             "hoge@f-scratch.com",
             forKey: BDashReport.CUSTOM_LOGIN_USER
             )
             
             let report: BDashReport = BDashReport(
             targets: ["https://demo2", "https://demo3"],
             trigger: "default",
             view: "商品詳細画面",
             preView: "商品一覧画面",
             page: "ItemDetailViewController",
             prePage: "ItemListViewController",
             eventFunc: "viewDidLoad",
             customProperty: customProperty
             )
             */
            
            if let view = self.navigationController?.view {
                // internal, webViewを制御
                self.wr.eventDelegate = { (type, param) in
                    guard let type = eventType(rawValue: type) else { return }
                    BDashLogger.debug("viewcontroller showMessage eventDelegate")
                    switch type {
                    case .EVENT_INTERNAL:
                        // MARK: .EVENT_INTERNAL
                        if let view = param["view"] as? String,
                           let date = param["date"] as? String,
                           let url = param["url"] as? String {
                            BDashLogger.debug("\(view)  \(date)  \(url)")
                        }
                        
                        
                        var paramStr = ""
                        for key in param.keys {
                            if let tmpParam = param[key] as? String {
                                if tmpParam.count > 0 {
                                    paramStr = paramStr + "\(key)=\(tmpParam)\n"
                                } else {
                                    paramStr = paramStr + "\(key)\n"
                                }
                            }
                        }
                        paramStr.removeLast()
                        if paramStr == "=" {
                            paramStr = ""
                        }
                        Task {
                            let alert = await UIAlertController(title: "EVENT_INTERNAL",
                                                                message: paramStr,
                                                                preferredStyle: .alert)
                            await alert.addAction(UIAlertAction(title: "OK", style: .default))
                            await self.present(alert, animated: true, completion: nil)
                        }
                        
                    case .EVENT_WEBVIEW:
                        // MARK: .EVENT_WEBVIEW
                        var paramStr = ""
                        if let url = param["url"] as? String {
                            paramStr = "\(url)"
                        }
                        Task {
                            let alert = await UIAlertController(title: "EVENT_WEBVIEW",
                                                                message: paramStr,
                                                                preferredStyle: .alert)
                            await alert.addAction(UIAlertAction(title: "OK", style: .default))
                            await self.present(alert, animated: true, completion: nil)
                        }
                    }
                }
                BDashLogger.debug("===========================current time 1===========================")
                BDashLogger.debug("\(Date().timeIntervalSince1970)")
                BDashLogger.debug("===========================current time 1===========================")
                _ = self.wr.showMessage(report: self.reports[0], onView: view, sizeUnit: "auto")
                // CUSTOM_LOGIN_USER　テスト時は以下のコメントアウトを外す
                // _ = self.wr.showMessage(report: report, onView: view)
                if self.waitBefore2ndSw.isOn == true {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                        BDashLogger.debug("===========================current time 2===========================")
                        BDashLogger.debug("\(Date().timeIntervalSince1970)")
                        BDashLogger.debug("===========================current time 2===========================")
                        _ = self.wr.showMessage(report: self.reports[1], onView: view, sizeUnit: "auto")
                        // CUSTOM_LOGIN_USER　テスト時は以下のコメントアウトを外す
                        // _ = self.wr.showMessage(report: report, onView: view)
                    }
                } else {
                    _ = self.wr.showMessage(report: self.reports[1], onView: view, sizeUnit: "auto")
                    // CUSTOM_LOGIN_USER　テスト時は以下のコメントアウトを外す
                    // _ = self.wr.showMessage(report: report, onView: view)
                    // print("customProperty: \(customProperty)")
                    // print("reportの中のcustomProperty: \(String(describing: report.customProperty))")
                }
            }
            self.showMessageButton.titleLabel?.alpha = 0.0
            UIView.animate(withDuration: 0.2) {
                self.showMessageButton.titleLabel?.alpha = 1.0
            }
        }
    }
    
    /// default valueタップ処理
    @IBAction func touchUpInsideDefaultValueButton(_ sender: Any) {
        if self.segControl.selectedSegmentIndex == 0 {
            self.setParameterToReports(selectedSeg: 0,
                                       baseUrl: BDashConstStruct.baseUrl,
                                       jsonName: "mobile/receptions/setting.json",
                                       targets: ["https://demo1"], trigger: "default",
                                       view: "画面1", preView: "画面1の前画面",
                                       page: "1",
                                       prePage: "0",
                                       eventFunc: "function 1",
                                       customProperty: ["key1A":"value1A","key1B":"value1B"])
        } else {
            self.setParameterToReports(selectedSeg: 1,
                                       baseUrl: BDashConstStruct.baseUrl,
                                       jsonName: "mobile/receptions/setting-2.json",
                                       targets: ["https://demo2", "https://demo3"],
                                       trigger: "boot",
                                       view: "画面2",
                                       preView: "画面2の前画面",
                                       page: "2",
                                       prePage: "3",
                                       eventFunc: "function 2",
                                       customProperty: ["key2A":"value2A","key2B":"value2B"])
        }
        self.tableView.reloadData()
    }
    
    /// previous valueタップ処理
    @IBAction func touchUpInsidePreviousValueButton(_ sender: Any) {
        let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
        if let tmpReports = ud?.value(forKey: keyOfPreviousSetting) as? [[AnyHashable: Any]], tmpReports.count > 1 {
            for i in 0...1 {
                let tmpReport = tmpReports[i]
                if let baseUrl = tmpReport[keyOfBaseUrlSetting] as? String,
                    let jsonName = tmpReport[keyOfJsonFileNameSetting] as? String {
                    self.inputedBaseUrl[i] = baseUrl
                    self.inputedJsonFile[i] = jsonName
                    self.setParameterToReports(selectedSeg: i,
                                               baseUrl: self.inputedBaseUrl[i],
                                               jsonName: self.inputedJsonFile[i],
                                               targets: tmpReport["targets"],
                                               trigger: tmpReport["trigger"],
                                               view: tmpReport["view"],
                                               preView: tmpReport["preView"],
                                               page: tmpReport["page"],
                                               prePage: tmpReport["prePage"],
                                               eventFunc: tmpReport["eventFunc"],
                                               customProperty: tmpReport["customProperty"])
                }
            }
        } else {
            let alert = UIAlertController(title: "エラー",
                                          message: "showMessageボタン押下前のため前回値がありません",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true, completion: nil)
        }
        self.tableView.reloadData()
    }
    
    /// wait 7s before apiタップ処理
    @IBAction func valueChange7waitSw(_ sender: UISwitch) {
        let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
        ud?.set(sender.isOn, forKey: waitSwitchKey)
        ud?.synchronize()
    }
    
    /// reportタップ処理
    @IBAction func touchUpInsideReportButton(_ sender: Any) {
        Task { @MainActor in
            // 入力情報を保持
            var report1 = await self.reports[0].convertToDic(isSaveToUserDefaults: true)
            report1[keyOfBaseUrlSetting] = inputedBaseUrl[0]
            report1[keyOfJsonFileNameSetting] = inputedJsonFile[0]
            
            var report2 = await self.reports[1].convertToDic(isSaveToUserDefaults: true)
            report2[keyOfBaseUrlSetting] = inputedBaseUrl[1]
            report2[keyOfJsonFileNameSetting] = inputedJsonFile[1]
            
            // url取得
            let baseUrl1 = self.inputedBaseUrl[0]
            let baseUrl2 = self.inputedBaseUrl[1]
            let jsonFile1 = self.inputedJsonFile[0]
            let jsonFile2 = self.inputedJsonFile[1]
            
            // base url, json file, urlを上書き
            BDashWebReception().setUrlParameterForReporter(baseUrls: [baseUrl1, baseUrl2],
                                                         jsonNames: [jsonFile1, jsonFile2])
            
            // url,fileNameを保持
            addHistory(key: keyOfFirstHistorySetting, text: baseUrl1 + "," + jsonFile1)
            addHistory(key: keyOfSecondHistorySetting, text: baseUrl2 + "," + jsonFile2)
            
            _ = BDashWebReception().report(obj: self.reports[0])
            if self.waitBefore2ndSw.isOn == true {
                // 2nd情報を退避させる
                self.reportWait.append(self.reports[1])
                self.urlWait.append(baseUrl2)
                self.jsonFileWait.append(jsonFile2)
                // 7秒ウエイト
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    // 退避させていた値を設定
                    BDashWebReception().setWaitParameter(url: self.urlWait[0], jsonName: self.jsonFileWait[0])
                    _ = BDashWebReception().report(obj: self.reportWait[0])
                    // 使用後は消す
                    self.reportWait.remove(at: 0)
                    self.urlWait.remove(at: 0)
                    self.jsonFileWait.remove(at: 0)
                }
            } else {
                _ = BDashWebReception().report(obj: self.reports[1])
            }
        }
    }
    
    /// closeMessageタップ処理
    @IBAction func touchUpInsideCloseMessageButton(_ sender: Any) {
        BDashLogger.debug("closeMessage Button")
        Task { @MainActor in
            self.wr.closeMessage()
        }
    }
    
    @IBAction func valueChangedDevSw(_ sender: UISwitch) {
        self.waitBeforeApiLabel.isHidden = (sender.isOn == false)
        self.waitBeforeApiSw.isHidden = (sender.isOn == false)
        self.tableView.reloadData()
    }
    
    @IBAction func touchUpInsideHistoryButton(_ sender: UIButton) {
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let textFieldHeight: CGFloat = 40
        let topMargin = statusBarHeight + textFieldHeight
        
        historyTableView = UITableView(frame: CGRect(x: 0, y: topMargin,
                                                     width: self.view.frame.width,
                                                     height: self.view.frame.height - topMargin))
        historyTableView.delegate = self
        historyTableView.dataSource = self
        historyTableView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        historyTableView.allowsSelection = false
        historyTableView.estimatedRowHeight = 50
        historyTableView.rowHeight = UITableView.automaticDimension
        historyTableView.tag = 2
        self.view.addSubview(historyTableView)
    }
    
    // MARK: Private
    
    private func setParameterToReports(selectedSeg: Int,
                                       baseUrl: String,
                                       jsonName: String,
                                       targets: Any?,
                                       trigger: Any?,
                                       view: Any?,
                                       preView: Any?,
                                       page: Any?,
                                       prePage: Any?,
                                       eventFunc: Any?,
                                       customProperty: Any?) {
        self.inputedBaseUrl[selectedSeg] = baseUrl
        self.inputedJsonFile[selectedSeg] = jsonName
        self.reports[selectedSeg].setValueBy(name: "targets", value: targets)
        self.reports[selectedSeg].setValueBy(name: "trigger", value: trigger)
        self.reports[selectedSeg].setValueBy(name: "view", value: view)
        self.reports[selectedSeg].setValueBy(name: "preView", value: preView)
        self.reports[selectedSeg].setValueBy(name: "page", value: page)
        self.reports[selectedSeg].setValueBy(name: "prePage", value: prePage)
        self.reports[selectedSeg].setValueBy(name: "eventFunc", value: eventFunc)
        self.reports[selectedSeg].setValueBy(name: "customProperty", value: customProperty)
    }
    
}

/// 選択入力ピッカーのデリゲートクラス
extension WebReceptionViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        let key: String = self.keys[pickerView.tag]
        switch key {
        case "trigger": return self.triggerPickerList.count
        case "view": return viewPickerList.count
        case "preView": return preViewPickerList.count
        case "page": return pagePickerList.count
        case "prePage": return prePagePickerList.count
        case "eventFunc": return eventFuncPickerList.count
        case "customProperty": return self.customPropertyPickerList.count
        default: return self.defaultPickerList.count
        }
    }
    
    // UIPickerViewに表示する配列
    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {
        let key: String = self.keys[pickerView.tag]
        switch key {
        case "trigger": return self.triggerPickerList[row]
        case "view": return viewPickerList[row]
        case "preView": return preViewPickerList[row]
        case "page": return pagePickerList[row]
        case "prePage": return prePagePickerList[row]
        case "eventFunc": return eventFuncPickerList[row]
        case "customProperty": return self.customPropertyPickerList[row]
        default: return self.defaultPickerList[row]
        }
    }
    
    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {
        let key = self.keys[pickerView.tag]
        let value: String = {
            switch key {
            case "trigger": return self.triggerPickerList[row]
            case "view": return viewPickerList[row]
            case "preView": return preViewPickerList[row]
            case "page": return pagePickerList[row]
            case "prePage": return prePagePickerList[row]
            case "eventFunc": return eventFuncPickerList[row]
            case "customProperty": return self.customPropertyPickerList[row]
            default: return self.defaultPickerList[row]
            }
        }()
        let index = self.segControl.selectedSegmentIndex
        if key == "customProperty" {
            self.reports[index].setValueBy(name: key, value: self.convertDic(dicStr: value))
        } else {
            self.reports[index].setValueBy(name: key, value: value)
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // MARK: Private
    
    private func convertDic(dicStr: Any?) -> [AnyHashable: Any]? {
        guard let dicStr = dicStr as? String else { return nil }
        if dicStr.count == 0 {
            BDashLogger.debug("nil")
            return nil
        }
        var tmpDic: [AnyHashable: Any] = [:]
        let keyAndValues = dicStr.components(separatedBy: ",")
        for keyAndValue in keyAndValues {
            let kv = keyAndValue.components(separatedBy: "=")
            if kv.count > 1 {
                tmpDic[kv[0]] = kv[1]
            }
        }
        if tmpDic.count == 0 {
            BDashLogger.debug("nil")
            return nil
        } else {
            BDashLogger.debug("\(tmpDic)")
            return tmpDic
        }
    }
    
}

// MARK: - TableViewDataSource
extension WebReceptionViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView.tag == 2 {
            var historyList: [String]
            if self.segControl.selectedSegmentIndex == 0 {
                historyList = getInputHistory(key: keyOfFirstHistorySetting)
            } else {
                historyList = getInputHistory(key: keyOfSecondHistorySetting)
            }
            return historyList.count + 1
        } else {
            return self.keys.count
        }
    }

}

// MARK: - TableViewDelegate
extension WebReceptionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView.tag {
        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
            if indexPath.row == 0 {
                // 先頭のセルをキャンセルにする
                cell.textLabel?.text = "cancel"
            } else {
                var historyList: [String]
                if self.segControl.selectedSegmentIndex == 0 {
                    historyList = getInputHistory(key: keyOfFirstHistorySetting)
                } else {
                    historyList = getInputHistory(key: keyOfSecondHistorySetting)
                }
                // 先頭がキャンセルのためindexから-1
                cell.tag = indexPath.row - 1
                cell.textLabel?.text = removeComma(value: historyList[indexPath.row - 1])
                cell.textLabel?.numberOfLines = 0
            }
            cell.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.inputFromHistory(sender:))))
            return cell
            
        default:
            let selectedPage = self.segControl.selectedSegmentIndex
            
            if let cell = tableView.dequeueReusableCell(withIdentifier: ReportDataInputCell.reuseId, for: indexPath) as? ReportDataInputCell {
                cell.inputTextField.delegate = self
                cell.inputTextField.tag = indexPath.row
                cell.titleLabel.isHidden = false
                cell.inputTextField.isHidden = false
                cell.colonLabel.isHidden = false
                // triggerのpickerが入っているかもしれないので初期化
                self.setCloseButton(textField: cell.inputTextField)
                
                let key = keys[indexPath.row]
                var value = ""

                if key != "base url" && key != "json file name" {
                    cell.inputTextField.clearButtonMode = UITextField.ViewMode.always
                } else {
                    cell.inputTextField.clearButtonMode = UITextField.ViewMode.never
                }

                switch key {
                case "base url":
                    BDashLogger.debug("\(self.inputedBaseUrl)")
                    value = self.inputedBaseUrl[selectedPage]
                case "json file name":
                    BDashLogger.debug("\(self.inputedJsonFile)")
                    value = self.inputedJsonFile[selectedPage]
                case "targets":
                    value = self.reports[selectedPage].targets?.joined(separator: ",") ?? ""
                    BDashLogger.debug("\(value)")
                case "customProperty":
                    self.setPicker(textField: cell.inputTextField, tag: indexPath.row)
                    if let custom = self.reports[selectedPage].customProperty {
                        for (key, dicValue) in custom {
                            value = value + "\(key)=\(dicValue),"
                        }
                    }
                    if value.count > 0 {
                        value.removeLast()
                    }
                    BDashLogger.debug("\(value)")
                default:
                    if let tmpValue = self.reports[selectedPage].getValueBy(name: key) as? String {
                        value = tmpValue
                    }
                    self.setPicker(textField: cell.inputTextField, tag: indexPath.row)
                    
                }
                cell.setup(title: key, inputedText: value)
                return cell
            } else {
                return UITableViewCell()
            }
        }
    }
    
    // MARK: Private
    
    private func setPicker(textField: UITextField?, tag: Int) {
        // 閉じるボタンを用意(inputViewを初期化していることに注意)
        self.setCloseButton(textField: textField)
        let picker = UIPickerView()
        picker.tag = tag
        picker.delegate = self
        picker.dataSource = self
        textField?.inputView = picker
    }
    
    private func setCloseButton(textField: UITextField?) {
        // 閉じるボタンを用意
        let kbToolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40))
        kbToolBar.barStyle = .default  // スタイルを設定
        kbToolBar.sizeToFit()  // 画面幅に合わせてサイズを変更
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let commitButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(touchUpInsideCloseButton))
        kbToolBar.items = [spacer, commitButton]
        textField?.inputAccessoryView = kbToolBar
        textField?.inputView = nil
    }
    
    @objc private func touchUpInsideCloseButton() {
        // Doneボタンがタップされたらtableをreload
        self.tableView.reloadData()
        self.view.endEditing(true)
    }

}

// MARK: - TextField
extension WebReceptionViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard string != "\n" else { return false }
        // 入力中にページsegment controlを操作された場合を考慮して一文字ずつ入れていく
        if let rawText = textField.text, let textRange = Range(range, in: rawText) {
            let text = rawText.replacingCharacters(in: textRange, with: string)
            BDashLogger.debug("updatedText:\(text)")
            let key = self.keys[textField.tag]
            let index = self.segControl.selectedSegmentIndex
            if key == "base url" {
                self.inputedBaseUrl[index] = text
            } else if key == "json file name" {
                self.inputedJsonFile[index] = text
            } else if key == "targets" {
                self.reports[index].targets = self.convertArr(arrStr: text)
            }
        }
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            let selectedPage = self.segControl.selectedSegmentIndex

            let key = self.keys[textField.tag]
            
            switch key {
            case "base url":
                break
            case "json file name":
                break
            case "targets":
                self.reports[selectedPage].targets = nil
            case "customProperty":
                self.reports[selectedPage].customProperty = nil
            default:
                self.reports[selectedPage].setValueBy(name: key, value: nil)
            }

            textField.resignFirstResponder()
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Private
    
    private func convertArr(arrStr: Any?) -> [String]? {
        guard let arrStr = arrStr as? String else { return nil }
        if arrStr.count == 0 {
            BDashLogger.debug("nil")
            return nil
        }
        let tmpTargets = arrStr.components(separatedBy: ",")
        BDashLogger.debug("\(tmpTargets)")
        return tmpTargets
    }
    
}

/// history機能
extension WebReceptionViewController {
    
    // UITableViewCellから履歴を入力
    @objc func inputFromHistory(sender: UITapGestureRecognizer) {
        if let cell = sender.view as? UITableViewCell {
            var historyList: [String]
            if self.segControl.selectedSegmentIndex == 0 {
                historyList = getInputHistory(key: keyOfFirstHistorySetting)
            } else {
                historyList = getInputHistory(key: keyOfSecondHistorySetting)
            }
            if historyList.count > 0 {
                let history = historyList[cell.tag]
                if removeComma(value: history) == cell.textLabel?.text {
                    var urlStrList: [String] = stringSeparatedBycomma(value: history)
                    if urlStrList.count > 1 {
                        self.inputedBaseUrl[self.segControl.selectedSegmentIndex] = urlStrList[0]
                        self.inputedJsonFile[self.segControl.selectedSegmentIndex] = urlStrList[1]
                        self.tableView.reloadData()
                    }
                }
            }
            
            self.historyTableView.removeFromSuperview()
        }
    }
    
    // MARK: Private
    
    // カンマ区切りの文字列を分解
    private func stringSeparatedBycomma(value: String) -> [String] {
        return value.components(separatedBy: ",")
    }
    
    // 文字配列をつなげる
    private func combineStrings(stringList: [String]) -> String {
        var resultStr = ""
        for value: String in stringList {
            resultStr += value
        }
        return resultStr
    }
    
    private func removeComma(value: String) -> String {
        return combineStrings(stringList: stringSeparatedBycomma(value: value))
    }

    // 新しく履歴に追加
    private func addHistory(key: String, text: String) {
        if text == "" {
            return
        }
        var histories = getInputHistory(key: key)
        for word in histories {
            if word == text {
                // すでに履歴にある場合は追加しない
                return
            }
        }
        // 新しいものを先頭に持ってくる
        histories.insert(text, at: 0)
        let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
        ud?.set(histories, forKey: key)
        
        // 最大10件まで保持
        if histories.count > 10 {
            removeHistory(key: key, index: 10)
        }
    }
    
    // 履歴を一つ削除
    private func removeHistory(key: String, index: Int) {
        var histories = getInputHistory(key: key)
        histories.remove(at: index)
        let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
        ud?.set(histories, forKey: key)
    }
    
    // 履歴取得
    private func getInputHistory(key: String) -> [String] {
        let ud = UserDefaults(suiteName: "com.sdk.myUserDefaults")
        if let histories = ud?.array(forKey: key) as? [String] {
            return histories
        }
        return []
    }
    
}

/// 埋め込みWEB接客で、WEBView読み込み時に動作
/// ※ お客様側で実装していただく想定の部分
extension WebReceptionViewController : WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        // ここでcancelを返すと下の処理に一切飛ばない
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.scheme = webView.url?.scheme
        BDashLogger.debug("scheme:\(String(describing: self.scheme))")
        Task {
            _ = await self.wr.performEachSchemeInEmbedding(url: webView.url)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {

        guard let httpURLResponse = navigationResponse.response as? HTTPURLResponse else { return }
        self.statusCode = httpURLResponse.statusCode
        
        if self.statusCode == 200 {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let confirmGetWebReceptionView = webView
        // java scriptを実行
        Task {
            await self.wr.performFinishProcessInEmbedding(statusCode: self.statusCode, webView: confirmGetWebReceptionView)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            BDashLogger.debug("必要に応じてエラー処理 : \(String(describing: self.scheme))")
    }
}
