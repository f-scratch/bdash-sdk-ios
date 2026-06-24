import UIKit
import SystemConfiguration

@objcMembers public class BDashSystemSoundTableView: UITableView, UITableViewDelegate, UITableViewDataSource {
    /**
     システムサウンドStruct
     */
    struct SystemSoundStruct {
        /// ファイル名
        var fileName = ""
        /// サウンド名辞書
        let soundNameDictionary = [
            "new-mail.caf":"鐘",
            "Voicemail.caf":"ボイスメール",
            "alarm.caf":"通知",
            "sq_alarm.caf":"通知", // ipod
            "sms-received1.caf":"トライトーン",
            "sms-received2.caf":"チャイム",
            "sms-received3.caf":"ガラス",
            "sms-received4.caf":"ホーン",
            "sms-received5.caf":"ベル",
            "sms-received6.caf":"エレクトリック",
            "Anticipate.caf":"予感",
            "Bloom.caf":"ブルーム",
            "Calypso.caf":"カリプソ",
            "Choo_Choo.caf":"機関車",
            "Descent.caf":"降下",
            "Fanfare.caf":"ファンファーレ",
            "Ladder.caf":"はしご",
            "Minuet.caf":"メヌエット",
            "News_Flash.caf":"ニュースフラッシュ",
            "Noir.caf":"ノアール",
            "Sherwood_Forest.caf":"シャーウッドの森",
            "Spell.caf":"スペル",
            "Telegraph.caf":"電報",
            "Tiptoes.caf":"つま先",
            "Typewriters.caf":"タイプライター",
            "Update.caf":"アップデート",
            "Tink.caf":"鈴の音",
            "Swish.caf":"スウォッシュ",
            "Suspense.caf":"サスペンス",
            "Bottle.aiff":"ボトル",
            "Frog.aiff":"フロッグ",
            "Submarine.aiff":"サブマリン",
            ]
        
        /**
         システムサウンドファイル名を名称に変換
         - returns:名称
         */
        func toString() -> String {
            let tmpFileNameStr = fileName.replacingOccurrences(of: "New/", with: "")
            if let f = self.soundNameDictionary[tmpFileNameStr] {
                return f
            }
            return "?"
        }
        
        /**
         イニシャライザ
         */
        init() {
        }
        
        /**
         イニシャライザ
         - parameter: f ファイル名
         */
        init(f:String) {
            fileName = f
        }
    }
    
    /// セル再利用ID
    let cellIdentifier = "BDashSystemSoundTableViewReuseCellIdentifier"
    /// システムサウンドファイル名一覧
    fileprivate var _allSystemSounds:Array<SystemSoundStruct> = []
    
    /**
     システムサウンドファイル名一覧取得
     - returns:システムサウンドファイル一覧 Array<SystemSoundStruct>
     */
    func allSystemSounds() -> Array<SystemSoundStruct> {
        
        // 初回呼び出し時に初期化
        if self._allSystemSounds.count == 0 {
            for fPath in ["/System/Library/Audio/UISounds/","/System/Library/Audio/UISounds/New/"] {
                do {
                    // ファイル名一覧
                    let fileNames:Array<String> = try FileManager.default.contentsOfDirectory(atPath: fPath)
                    
                    for fileName in fileNames {
                        // システム効果音
                        if fileName.hasSuffix(".caf") {
                            var tmp = SystemSoundStruct()
                            // ファイル名
                            tmp.fileName = fileName
                            if fPath.hasSuffix("New/") {
                                tmp.fileName = "New/" + fileName
                            }
                            
                            // 登録された通知音ぽい音だけリスト化する
                            if tmp.toString() != "?" {
                                self._allSystemSounds.append(tmp)
                            }
                        }
                    }
                } catch {
                    BDashLogger.debug("\(error)")
                }
            }
        }
        return self._allSystemSounds
    }
    
    /**
     正規表現にマッチした回数を返す
     - parameter: targetString 対象文字列
     - parameter: pattern 正規表現パターン
     */
    func getMatchCount(_ targetString: String, pattern: String) -> Int {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let targetStringRange = NSRange(location: 0, length: (targetString as NSString).length)
            return regex.numberOfMatches(in: targetString, options: [], range: targetStringRange)
        } catch {
            BDashLogger.debug("error: getMatchCount")
        }
        return 0
    }
    
    /**
     イニシャライザ
     */
    public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)

        self.dataSource = self
        self.delegate = self
        // セルの単一選択
        self.allowsMultipleSelection = false
        // 初期化
        _ = self.allSystemSounds()
    }
    /**
     イニシャライザ
     */
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    /**
     セルの数を返すデリゲート
     */
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self._allSystemSounds.count
    }
    internal func getCellCount(section: Int) -> Int {
        return self._allSystemSounds.count
    }
    /**
     セルを返すデリゲート
     */
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // 再利用するCellを取得する.
        var cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier)
        
        if cell == nil {
            cell = UITableViewCell()
        }
        // Cellに値を設定する.
        cell!.textLabel!.text = self._allSystemSounds[indexPath.row].toString()
        
        // チェックマークをつける
        if self._allSystemSounds[indexPath.row].fileName == BDashNotification.getInstance().soundFileName {
            cell!.accessoryType = .checkmark
        }
        // ハイライトなし
        cell!.selectionStyle = .none
        
        return cell!
    }
    /**
     セルがタップされたときのデリゲート
     */
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // プッシュ通知クラスにサウンドIDを保存
        BDashNotification.getInstance().soundFileName = self._allSystemSounds[indexPath.row].fileName
        
        // チェックマーク
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .checkmark
        }
        self.reloadData()
        BDashNotification.getInstance().vibrate()
        BDashNotification.getInstance().soundSE()
    }
    /**
     セル選択解除時のデリゲート
     */
    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        // チェックマーク外す
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .none
        }
    }
}
