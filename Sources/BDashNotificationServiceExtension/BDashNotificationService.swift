import UserNotifications
import UIKit
import UniformTypeIdentifiers

/// リッチPush通知用 Notification Service Extension
extension BDashNotificationService: @unchecked Sendable {}

class BDashNotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    // contentHandler を高々1回だけ呼ぶためのガードフラグ
    private var didDeliver = false
    
    // 固定文字列：com.f_scratch.bdash.mobile.download.image
    static let kDownloadImageDomain:String = "com.f_scratch.bdash.mobile.download.image"

    // 添付画像のサイズ上限。10MB を超える画像は添付せず、画像なしの通常通知として配信する。
    private static let kMaxImageAttachmentByteSize: Int = 1000 * 1000 * 10

    // メディアダウンロードのタイムアウト（秒）。
    private static let kDownloadTimeoutSeconds: TimeInterval = 30

    // タイムアウトを明示設定したメディアダウンロード用 URLSession。
    private lazy var mediaDownloadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = BDashNotificationService.kDownloadTimeoutSeconds
        configuration.timeoutIntervalForResource = BDashNotificationService.kDownloadTimeoutSeconds
        return URLSession(configuration: configuration)
    }()
    
    // 拡張ターゲットの Info.plist から AppGroupIdentifier を取得
    // （Bundle.main は通知拡張自身のバンドルを指す）
    private let groupIdentifier: String = {
        return Bundle.main.infoDictionary?["APP_BDASH_APP_GROUP_ID"] as? String ?? ""
    }()
    
    // 日時スタンプの文字列変換時の指定フォーマット
    private var dateFormatter: DateFormatter = DateFormatter()
    
    // 文字コードがShiftJISのメディアURLを読取対象とするか
    private let isValidShiftJIS: Bool = true
    
    
    override init() {
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyyMMddHHmmssSSS"
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        nonisolated(unsafe) var urlPathString :String!
        var urlCandidates: [URL] = []
        let fcmOptions = request.content.userInfo["fcm_options"] as? [AnyHashable:Any]
        if let fcmApi = request.content.userInfo["fcm_api"] as? String {
            if  fcmApi == "v1"{
                // "image"はurlエンコード済み
                guard let urlString = fcmOptions?["image"] as? String else {
                    self.debugLog("failure: couldn't create available media URL")
                    self.deliver()
                    return
                }
                urlPathString = urlString
                urlCandidates = makeAvailableMediaURLCandidates(urlString)
            }
            else {
                // "mediaUrl"はurlエンコード済み
                guard let urlString = request.content.userInfo["mediaUrl"] as? String else {
                    self.debugLog("failure: couldn't create available media URL")
                    self.deliver()
                    return
                }
                urlPathString = urlString
                urlCandidates = makeAvailableMediaURLCandidates(urlString)
            }
        }

        // fcm_api キーが無い等で候補URLが解決できなかった場合のクラッシュ防止
        guard !urlCandidates.isEmpty else {
            self.debugLog("failure: media URL is nil (fcm_api absent or unresolved)")
            deliver()
            return
        }

        // 候補URLを先頭から順にダウンロードし、画像として有効なものを採用する。
        // 正常系では先頭の素URLで1回ダウンロードして完了する（二重ダウンロード解消）。
        downloadMedia(from: urlCandidates, index: 0, urlPathString: urlPathString)
    }

    // 候補URLを順にダウンロードして添付を試みる（有効な画像が得られた時点で確定）
    private func downloadMedia(from candidates: [URL], index: Int, urlPathString: String) {
        guard index < candidates.count else {
            // 全候補が無効だった場合は画像なしで配信
            self.debugLog("failure: no valid image found in any candidate URL")
            self.deliver()
            return
        }
        let url = candidates[index]
        self.mediaDownloadSession.downloadTask(with: url) { (location, response, error) in
            guard let location = location else {
                self.debugLog("failure: location is nil, error: \(String(describing: error))")
                // 次の候補へフォールバック
                self.downloadMedia(from: candidates, index: index + 1, urlPathString: urlPathString)
                return
            }
            // ダウンロード結果が画像としてデコード可能か検証（旧 existsAttachedImageIn 相当を1回のDLで実施）
            guard let mediaData = try? Data(contentsOf: location), UIImage(data: mediaData) != nil else {
                self.debugLog("failure: downloaded data is not a valid image (candidate index \(index))")
                self.downloadMedia(from: candidates, index: index + 1, urlPathString: urlPathString)
                return
            }

            // 添付画像が上限（10MB）を超える場合は添付しない。
            // 当該候補をスキップし、最終的に画像なしの通常通知として配信されるようにする。
            guard mediaData.count <= BDashNotificationService.kMaxImageAttachmentByteSize else {
                self.debugLog("failure: image exceeds limit (candidate index \(index), size \(mediaData.count) bytes)")
                self.downloadMedia(from: candidates, index: index + 1, urlPathString: urlPathString)
                return
            }

            // 画像の実体（マジックナンバー）から UTI を判定する。
            // 署名付き/クエリ付きURLでは末尾から拡張子が取れず、従来は .gif 固定となり
            // ファイルの宣言UTIが実体と不一致になっていた。その結果、展開ビューでは
            // 表示できても折りたたみバナーのサムネイルが出ない不具合が起きていたため、
            // 拡張子推測ではなく実体から UTI を確定する。
            let imageType = self.detectImageUTType(from: mediaData, urlPathString: urlPathString)
            // UTI から正しいファイル拡張子を決定（取得できなければ従来通り gif にフォールバック）
            let pathExtension = imageType.preferredFilenameExtension ?? "gif"

            // 添付メディアをURLに保存
            let filePath = NSTemporaryDirectory() + UUID().uuidString + "." + pathExtension
            let temporarySaveURL = URL(fileURLWithPath: filePath)
            do {
                try FileManager.default.copyItem(at: location, to: temporarySaveURL)
            } catch {
                self.debugLog("catched: exception at FileManager.default.copyItem(), error: \(error)")
                self.deliver()
                return
            }

            let date = self.dateFormatter.string(from: Date())
            do {
                // typeHint に実体の UTI を明示することで、拡張子やサーバの Content-Type に
                // 依存せず、折りたたみバナーのサムネイルも確実に描画されるようにする。
                let attachmentOptions: [String: Any] = [
                    UNNotificationAttachmentOptionsTypeHintKey: imageType.identifier
                ]
                let attachment = try UNNotificationAttachment(identifier: BDashNotificationService.kDownloadImageDomain, url: temporarySaveURL, options: attachmentOptions)
                self.bestAttemptContent?.attachments = [attachment]
                // shared container に上書き保存
                let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupIdentifier)
                if var sharedMediaUrl = containerUrl?.appendingPathComponent(date + UUID().uuidString) {
                    sharedMediaUrl.appendPathExtension(pathExtension)
                    if( FileManager.default.fileExists(atPath: sharedMediaUrl.path ) ) {
                        try FileManager.default.removeItem(at: sharedMediaUrl)
                    }
                    try FileManager.default.copyItem(at: location, to: sharedMediaUrl)
                    self.bestAttemptContent?.userInfo["_sharedMediaPath"] = "file://" + sharedMediaUrl.path
                }
            } catch {
                self.debugLog("catched: exception occurs when overwriting in shared container")
            }
            self.deliver()
        }.resume()
    }
    
    override func serviceExtensionTimeWillExpire() {
        deliver()
    }

    // contentHandler を高々1回だけ呼ぶ（全ての終了ルートから経由する）
    private func deliver() {
        guard !didDeliver else { return }
        didDeliver = true
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    // 拡張子の文字列を取得する
    private func getPathExtension(_ path: String) -> String {
        let pattern = "\\.\\w+$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }
        let matches = regex.firstMatch(in: path, range: NSRange(location: 0, length: path.count))
        let pathString = path as NSString
        guard let range = matches?.range(at: 0) else { return "" }
        return String(pathString.substring(with: range).suffix(range.length - 1))
    }

    // ダウンロード済みデータの実体から画像の UTType を判定する。
    // 1) 先頭バイト（マジックナンバー）で JPEG/PNG/GIF を確定（最も信頼できる）
    // 2) 判定できなければ URL 末尾の拡張子をヒントに UTType を解決
    // 3) それでも不明なら汎用の .image を返す
    private func detectImageUTType(from data: Data, urlPathString: String) -> UTType {
        if let byType = self.imageUTTypeFromMagicNumber(data) {
            return byType
        }
        let ext = self.getPathExtension(urlPathString)
        if !ext.isEmpty, let byExt = UTType(filenameExtension: ext.lowercased()), byExt.conforms(to: .image) {
            return byExt
        }
        return .image
    }

    // 画像データ先頭のマジックナンバーから UTType を判定する
    private func imageUTTypeFromMagicNumber(_ data: Data) -> UTType? {
        guard data.count >= 4 else { return nil }
        let bytes = [UInt8](data.prefix(12))
        // JPEG: FF D8 FF
        if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return .jpeg
        }
        // PNG: 89 50 4E 47
        if bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return .png
        }
        // GIF: 47 49 46 38 ("GIF8")
        if bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x38 {
            return .gif
        }
        // WebP: "RIFF"...."WEBP"
        if bytes.count >= 12,
           bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
           bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50 {
            return .webP
        }
        return nil
    }

    // メディアURLの候補（構文上有効なもの）を返却する。
    // 以前は候補ごとに Data(contentsOf:) で同期ダウンロードして存在確認していたが、
    // それだと本番のdownloadTaskと合わせて同一画像を2回ダウンロードしてしまうため、
    // ここではダウンロードせず構文上の候補のみを返し、実際の画像妥当性は
    // downloadTask 完了後に UIImage(data:) で検証する。
    // 素のURL → (ShiftJIS有効時)エンコード版URL の順で候補を返す。
    private func makeAvailableMediaURLCandidates(_ urlString: String?) -> [URL] {
        var candidates: [URL] = []
        guard let string = urlString else { return candidates }
        if let url = URL(string: string), isAllowedMediaURL(url) {
            candidates.append(url)
        }
        if self.isValidShiftJIS {
            if let encodedString = encodeFrom(ShiftJISString: string),
               let url = URL(string: encodedString), isAllowedMediaURL(url) {
                candidates.append(url)
            }
        }
        return candidates
    }

    // ペイロード由来のメディアURLは https のみ許可する。
    // file:// やローカル/平文スキームを除外し、任意サーバー・ローカルファイルへのアクセスを防ぐ。
    private func isAllowedMediaURL(_ url: URL) -> Bool {
        return url.scheme?.lowercased() == "https"
    }
    
    // ShiftJISのURL文字列をパーセントエンコード(UTF-8)する
    private func encodeFrom(ShiftJISString: String) -> String? {
        var byteArray: [UInt8] = []
        let stringArray: [String] = ShiftJISString.map { String($0) }
        var index: Int = 0
        while index < stringArray.count {
            let char: String = stringArray[index]
            if char == "%" , (index + 2) < stringArray.count {
                let towChar = stringArray[index+1...index+2].joined()
                if let charCode = UInt8(towChar, radix: 16) {
                    byteArray.append(charCode)
                    index += 3
                }
            } else if char == "+", let hexValue = " ".utf8.first {
                byteArray.append(hexValue)
                index += 1
            } else if let charCode = Array(char.utf8).first {
                byteArray.append(charCode)
                index += 1
            }
        }
        if let urlString = NSString(bytes: byteArray,
                                 length: byteArray.count,
                                 encoding: String.Encoding.shiftJIS.rawValue),
           let percentURLString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return percentURLString
        } else {
            debugLog("failure: couldn't get encoded url string from ShiftJIS")
            return nil
        }
    }
    
    private func debugLog(_ log: String) {
        #if DEBUG
        NSLog("debugLog: %@", log);
        #endif
    }
    
}
