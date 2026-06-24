import Foundation

@objcMembers
public final class BDashReport: NSObject, Sendable {
    nonisolated(unsafe) public var targets: [String]?
    nonisolated(unsafe) public var trigger: String?
    nonisolated(unsafe) public var view: String?
    nonisolated(unsafe) public var preView: String?
    nonisolated(unsafe) public var page: String?
    nonisolated(unsafe) public var prePage: String?
    nonisolated(unsafe) public var eventFunc: String?
    nonisolated(unsafe) public var customProperty: [AnyHashable: Any]?
    
    // トリガー固定値
    public static let TRIGGER_BOOT = "boot"
    public static let TRIGGER_VIEW = "view"
    public static let TRIGGER_DEFAULT = "default"
    public static let TRIGGER_TOUCH = "touch"
    public static let TRIGGER_SCROLL = "scroll"
    
    // カスタムプロパティの予約語
    public static let CUSTOM_LOGIN_USER = "__loginUserId"
    
    public init(targets: [String]?, trigger: String?, view: String?, preView: String?, page: String?, prePage: String?, eventFunc: String?, customProperty: [AnyHashable: Any]?) {
        self.targets = targets
        self.trigger = trigger
        self.view = view
        self.preView = preView
        self.page = page
        self.prePage = prePage
        self.eventFunc = eventFunc
        self.customProperty = customProperty
    }
    
    public func getValueBy(name: String) -> Any? {
        switch name {
        case WebReceptionKey.targets:
            return targets
        case WebReceptionKey.trigger:
            return trigger
        case WebReceptionKey.view:
            return view
        case WebReceptionKey.preView:
            return preView
        case WebReceptionKey.page:
            return page
        case WebReceptionKey.prePage:
            return prePage
        case WebReceptionKey.eventFunc:
            return eventFunc
        case WebReceptionKey.customProperty:
            return customProperty
        default:
            return nil
        }
    }
    
    public func setValueBy(name: String, value: Any?) {
        switch name {
        case WebReceptionKey.targets:
            self.targets = value as? [String]
        case WebReceptionKey.trigger:
            if let value = value as? String {
                self.trigger = value
            } else {
                self.trigger = nil
            }
        case WebReceptionKey.view:
            self.view = value as? String
        case WebReceptionKey.preView:
            self.preView = value as? String
        case WebReceptionKey.page:
            self.page = value as? String
        case WebReceptionKey.prePage:
            self.prePage = value as? String
        case WebReceptionKey.eventFunc:
            self.eventFunc = value as? String
        case WebReceptionKey.customProperty:
            self.customProperty = value as? [AnyHashable: Any]
        default:
            break
        }
    }
    
    public func convertToDic(isSaveToUserDefaults: Bool) async -> [AnyHashable: Any] {
        var dic: [AnyHashable: Any] = [:]
        
        if let targets = self.targets, targets.isEmpty == false {
            dic[WebReceptionKey.targets] = targets
        }
        if let trigger = self.trigger {
            dic[WebReceptionKey.trigger] = trigger
        }
        if let view = self.view, view.isEmpty == false {
            dic[WebReceptionKey.view] = view
        }
        if let preView = self.preView, preView.isEmpty == false {
            dic[WebReceptionKey.preView] = preView
        }
        if let page = self.page, page.isEmpty == false {
            dic[WebReceptionKey.page] = page
        }
        if let prePage = self.prePage, prePage.isEmpty == false {
            dic[WebReceptionKey.prePage] = prePage
        }
        if let eventFunc = self.eventFunc, eventFunc.isEmpty == false {
            dic[WebReceptionKey.eventFunc] = eventFunc
        }
        if let customProperty = self.customProperty, customProperty.isEmpty == false {
            dic[WebReceptionKey.customProperty] = customProperty
        }
        return dic
    }
}
