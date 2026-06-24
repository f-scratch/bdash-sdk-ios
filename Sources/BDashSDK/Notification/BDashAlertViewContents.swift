import UIKit

@available(iOS 9.0, *)
public class BDashAlertViewContents {
    /// 通知タイトル
    public var title: String?
    /// 通知本文
    public var body: String?
    /// 通知添付画像
    public var image: UIImage?
    /// フォアグラウンドで `_sharedMediaPath` が無い場合に SDK が自前取得する画像URL（NSE非依存フォールバック）
    public var fallbackImageURLString: String?
    /// 通知添付画像の表示有無
    public var showImage: Bool = false
    /// 通知音の設定
    public var playSound: Bool = false
    /// 通知カスタムパラメータ
    public var param: String?
    /// 通知ボタン用カスタムパラメータ
    public var notificationParam: String?
    /// 添付画像の配置
    public var imagePosition: ImagePosition = .top
    /// 通知アラート背景に透過色が必要か
    public var isWithOverray: Bool = true
    /// 通知アラート型
    public var alertType: BDashAlertType = .BDashAlert
    /// 通知アラートのボタン設定情報の配列
    public var alertButtons: [BDashAlertButtonContents] = []

    /// 通知アラートの表示型
    public enum BDashAlertType: Int, Sendable {
        case BDashAlert = 0
        case BDashDoubleButtonAlert = 1
        public static let allCase: [BDashAlertType] = [.BDashAlert, .BDashDoubleButtonAlert]
    }

    /// 添付画像の配置位置
    public enum ImagePosition {
        case top
        case bottom
    }

    public init() {}

    public init(title: String?, body: String?, image: UIImage?,
            showImage: Bool = false,
            playSound: Bool = false,
            param: String? = nil,
            notificationParam: String? = nil,
            imagePosition: ImagePosition = .top,
            isWithOverray: Bool = true,
            alertType: BDashAlertType = .BDashAlert) {
        self.title = title
        self.body = body
        self.image = image
        self.showImage = showImage
        self.playSound = playSound
        self.param = param
        self.notificationParam = notificationParam
        self.imagePosition = imagePosition
        self.isWithOverray = isWithOverray
        self.alertType = alertType
    }

    public func setAlertType(of theType: BDashAlertType) { self.alertType = theType }
    public func getAlertType() -> BDashAlertType { return self.alertType }
    public func addAlertButton(of theContent: BDashAlertButtonContents) {
        self.alertButtons.append(theContent)
    }

    public func validateButtonLayout() {
        if self.alertType == .BDashAlert {
            return
        }
        let hasDoubleButtonContents: Bool = {
            if alertButtons.count >= BDashAlertType.allCase.count,
               alertButtons.indices.contains(0),
               alertButtons.indices.contains(1) {
                return true
            }
            return false
        }()
        // 通知アラート表示の指定が不適切な場合
        if !hasDoubleButtonContents {
            self.alertType = .BDashAlert
            return
        }
        // 正常な配置の場合
        if (alertButtons[0].layout == .left && alertButtons[1].layout == .right) ||
           (alertButtons[0].layout == .right && alertButtons[1].layout == .left) {
            return
        }
        // 指定配置が競合している場合
        if alertButtons[0].layout == .left && alertButtons[1].layout == .left {
            alertButtons[0].layout = .right
            alertButtons[1].layout = .left
            return
        } else if alertButtons[0].layout == .right && alertButtons[1].layout == .right {
            alertButtons[0].layout = .left
            alertButtons[1].layout = .right
            return
        }
        // 両方の配置が未定義の場合 (規定値を適用)
        if (alertButtons[0].layout == nil && alertButtons[1].layout == nil) {
            alertButtons[0].layout = .left
            alertButtons[1].layout = .right
            return
        }
        // 片方の配置が未定義の場合
        if alertButtons[0].layout == nil {
            if alertButtons[1].layout == .left {
                alertButtons[0].layout = .right
            } else if alertButtons[1].layout == .right {
                alertButtons[0].layout = .left
            }
            return
        } else if alertButtons[1].layout == nil {
            if alertButtons[0].layout == .left {
                alertButtons[1].layout = .right
            } else if alertButtons[0].layout == .right {
                alertButtons[1].layout = .left
            }
            return
        }
    }
}
