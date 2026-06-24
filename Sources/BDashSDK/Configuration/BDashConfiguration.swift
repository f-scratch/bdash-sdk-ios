import Foundation

/// SDK設定値の読み込みを担当するクラス
/// 導入先アプリの Info.plist から Bundle.main.infoDictionary で設定値を読み取る
public final class BDashConfiguration: Sendable {

    public static let shared = BDashConfiguration()

    private init() {}

    /// アカウントID
    public var accountId: String {
        stringValue(forKey: "APP_BDASH_ACCOUNT_ID")
    }

    /// アプリID
    public var appId: String {
        stringValue(forKey: "APP_BDASH_APP_ID")
    }

    /// App Group Identifier（リッチプッシュ通知利用時のみ必要）
    public var appGroupId: String {
        stringValue(forKey: "APP_BDASH_APP_GROUP_ID")
    }

    /// Info.plist から文字列値を取得する
    private func stringValue(forKey key: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? ""
    }
}
