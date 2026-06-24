import Foundation

/// イベントビルダー
@objcMembers
open class EventBuilder: BaseBuilder {
    /// イベントカテゴリ名
    public var eventCategory: String!

    /// イベントアクション名
    public var eventActionName: String!

    /// イベント値
    public var eventValue: String!

    /// ラベル
    public var eventLabel: String!

    /// イベントマップ
    public var eventMap: NSDictionary!

    public override init() {
        super.init()
        super.internalType = BDashConst.kInternalTypeEvent
        super.eventDateTime = TrackUtil().generateEventDate()
    }

    override open func mapping2dictionary() -> NSMutableDictionary {
        let result = super.mapping2dictionary()

        if self.eventCategory != nil {
            result.setValue(self.eventCategory, forKey: "eventCategory")
        }
        if self.eventActionName != nil {
            result.setValue(self.eventActionName, forKey: "eventActionName")
        }
        if self.eventValue != nil {
            result.setValue(self.eventValue, forKey: "eventValue")
        }
        if self.eventLabel != nil {
            result.setValue(self.eventLabel, forKey: "eventLabel")
        }
        if self.eventMap != nil {
            let convertEventMap = TrackUtil().removeEmptyKeyForDictionary(self.eventMap)
            result.setValue(convertEventMap, forKey: "eventMap")
        }

        return result
    }
}
