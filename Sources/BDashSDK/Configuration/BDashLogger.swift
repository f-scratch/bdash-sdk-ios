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
