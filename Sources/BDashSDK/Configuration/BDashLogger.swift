import Foundation
import os

/// ログの重要度。設定した `logLevel` 以上の重要度のログのみ出力される。
/// 重要度が高い順に error > warning > info > debug。`off` は全出力を抑制。
public enum BDashLogLevel: Int, Comparable, Sendable {
    case off
    case error
    case warning
    case info
    case debug

    public static func < (lhs: BDashLogLevel, rhs: BDashLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// os.Logger ベースの統一ログ出力クラス。
///
/// 出力可否は実行時の `logLevel`（デフォルト `.error`）で制御する。
/// `BDashLogger.setLogLevel(.debug)` のように導入アプリ側から変更できる。
/// 出力内容は DEBUG ビルドでは `privacy: .public`、リリースビルドでは `privacy: .private`
/// となり、本番環境では機密情報が平文出力されない。
public struct BDashLogger: Sendable {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.f-scratch.bdash.sdk",
        category: "BDashSDK"
    )

    /// 現在のログレベル。デフォルトは `.error`。
    nonisolated(unsafe) private static var _level: BDashLogLevel = .error

    /// 現在のログレベルを取得する。
    public static var logLevel: BDashLogLevel { _level }

    /// ログレベルを設定する。設定値以上の重要度のログのみ出力される。
    /// - Parameter level: 出力する最小の重要度。`.off` で全出力を抑制。
    public static func setLogLevel(_ level: BDashLogLevel) {
        _level = level
    }

    public func debugData(_ data: Data) {}

    // MARK: - 秘匿情報のマスキング

    /// トラッキング/Web接客パラメータで伏せ字にすべき既定の秘匿キー。
    /// （識別子・トークン・個人情報。表記ゆれ（`uuId`/`uuid`）も吸収する）
    static let defaultSensitiveKeys: Set<String> = [
        "appId", "accountId", "customId", "uuId", "uuid",
        "idfa", "deviceId", "tokenId", "loginUserId", "trackings"
    ]

    /// トークン・識別子等の秘匿文字列をマスクする。
    /// 先頭5文字のみ残し、以降を `****` に伏せる。
    /// 例: `"abcdef123456"` -> `"abcde****"`、空文字 -> `"(empty)"`、`nil` -> `"(nil)"`。
    /// 5文字以下の場合はそのまま返す（伏せる対象が無いため）。
    /// - Parameter value: マスク対象の文字列。`nil` も安全に扱える。
    /// - Returns: マスク済み文字列。
    static func mask(_ value: String?) -> String {
        guard let value else { return "(nil)" }
        if value.isEmpty { return "(empty)" }
        guard value.count > 5 else { return value }
        return "\(value.prefix(5))****"
    }

    /// `Data` を内容を出さずにサイズのみで表現する。
    /// サーバーレスポンス等、本文に秘匿情報を含みうる `Data` のログ用。
    /// - Parameter data: 対象データ。`nil` も安全に扱える。
    /// - Returns: `"(N bytes)"` 形式の文字列。
    static func mask(data: Data?) -> String {
        guard let data else { return "(nil)" }
        return "(\(data.count) bytes)"
    }

    /// URL からクエリ・フラグメントを除去し、`host + path` のみに丸める。
    /// クエリやフラグメントに秘匿パラメータが乗りうるため除外する。
    /// - Parameter urlString: 対象 URL 文字列。
    /// - Returns: `"host/path"` 形式の文字列。解析不能時は `"(invalid url)"`。
    static func mask(urlString: String?) -> String {
        guard let urlString,
              let url = URL(string: urlString),
              var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "(invalid url)" }
        comps.query = nil
        comps.fragment = nil
        return "\((comps.host ?? ""))\(comps.path)"
    }

    /// 辞書から秘匿キーの値を伏せ字に置換した要約文字列を返す。
    /// トラッキングパラメータ等、秘匿キーと非秘匿キーが混在する辞書のログ用。
    /// 値は `mask(_:)`（先頭5文字＋`****`）に置換し、キー名と先頭は残す。
    /// `trackings` のような秘匿キーは値の型に関わらず `***` で完全に伏せる。
    /// - Parameters:
    ///   - dictionary: 対象辞書。
    ///   - sensitiveKeys: 伏せ字にするキー集合。
    /// - Returns: マスク済みの説明文字列。
    static func maskedDescription(of dictionary: NSDictionary,
                                  sensitiveKeys: Set<String> = defaultSensitiveKeys) -> String {
        let masked = NSMutableDictionary(dictionary: dictionary)
        for case let key as String in dictionary.allKeys where sensitiveKeys.contains(key) {
            if let stringValue = masked[key] as? String {
                masked[key] = mask(stringValue)
            } else {
                // 配列・辞書など文字列以外の秘匿値は完全に伏せる
                masked[key] = "***"
            }
        }
        return masked.description
    }

    public static func debug(_ message: @autoclosure () -> String) {
        guard _level >= .debug else { return }
        let text = message()
        #if DEBUG
        logger.debug("\(text, privacy: .public)")
        #else
        logger.debug("\(text, privacy: .private)")
        #endif
    }

    public static func info(_ message: @autoclosure () -> String) {
        guard _level >= .info else { return }
        let text = message()
        #if DEBUG
        logger.info("\(text, privacy: .public)")
        #else
        logger.info("\(text, privacy: .private)")
        #endif
    }

    public static func warning(_ message: @autoclosure () -> String) {
        guard _level >= .warning else { return }
        let text = message()
        #if DEBUG
        logger.warning("\(text, privacy: .public)")
        #else
        logger.warning("\(text, privacy: .private)")
        #endif
    }

    public static func error(_ message: @autoclosure () -> String) {
        guard _level >= .error else { return }
        let text = message()
        #if DEBUG
        logger.error("\(text, privacy: .public)")
        #else
        logger.error("\(text, privacy: .private)")
        #endif
    }
}
