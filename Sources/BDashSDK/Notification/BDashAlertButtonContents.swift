@available(iOS 9.0, *)
public class BDashAlertButtonContents {
    /// ボタン配置 (ペイロード値)
    public var number: Int?
    /// ボタン配置
    public var layout: ButtonLayout?
    /// ボタン添付パラメータ
    public var notificationParam: String?
    /// ボタンラベル
    public var label: String?
    
    public enum ButtonLayout: Int {
        case left = 1
        case right = 2
        public func getString() -> String {
            switch self {
            case .left: return "LEFT"
            case .right: return "RIGHT"
            }
        }
    }
    
    init() {}
    
    public init(number: Int? = nil,
         notificationParam: String? = nil,
         label: String? = nil,
         layout: ButtonLayout? = nil) {
        self.number = number
        self.notificationParam = notificationParam
        self.label = label
        self.layout = ButtonLayout(rawValue: self.number ?? -1) ?? nil
    }
}
