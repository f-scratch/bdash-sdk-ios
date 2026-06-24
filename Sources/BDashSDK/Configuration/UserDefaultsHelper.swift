import Foundation

/// UserDefaults操作を集約するヘルパークラス
/// 既存のsuite name（com.sdk.myUserDefaults）との後方互換性を維持する
public final class UserDefaultsHelper: Sendable {

    public static let shared = UserDefaultsHelper()

    private static let suiteName = "com.sdk.myUserDefaults"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: Self.suiteName)
    }

    private init() {}

    // MARK: - String

    public func getString(_ key: String) -> String {
        defaults?.string(forKey: key) ?? ""
    }

    public func setString(_ key: String, value: String) {
        defaults?.set(value, forKey: key)
        defaults?.synchronize()
    }

    // MARK: - Bool

    public func getBool(_ key: String) -> Bool {
        defaults?.bool(forKey: key) ?? false
    }

    public func setBool(_ key: String, value: Bool) {
        defaults?.set(value, forKey: key)
        defaults?.synchronize()
    }

    // MARK: - Register Defaults

    public func register(defaults dictionary: [String: Any]) {
        self.defaults?.register(defaults: dictionary)
    }

    // MARK: - Remove

    public func remove(_ key: String) {
        defaults?.removeObject(forKey: key)
        defaults?.synchronize()
    }
}
