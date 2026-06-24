import Foundation

/// クラッシュビルダー
@objcMembers
open class ExceptionBuilder: BaseBuilder {
    /// クラッシュ名
    public var crashName: String!

    /// クラッシュの概要
    public var crashDescription: String!

    /// クラッシュが致命的か
    public var crashFatal: Bool!

    /**
     コンストラクタ
     - returns: なし
     */
    public override init() {
        super.init()
        super.internalType = BDashConst.kInternalTypeCrash
        super.eventDateTime = TrackUtil().generateEventDate()
    }

    /**
     builderの情報をmapオブジェクトに変換
     - returns: Dictionary<String, String>オブジェクト（キー、バリュー）
     */
    override open func mapping2dictionary() -> NSMutableDictionary {
        let result = super.mapping2dictionary()

        if self.crashName != nil {
            result.setValue(self.crashName, forKey: "crashName")
        }
        if self.crashDescription != nil {
            result.setValue(self.crashDescription, forKey: "crashDescription")
        }
        if self.crashFatal != nil {
            let strCrash = self.crashFatal == true ? "true" : "false"
            result.setValue(strCrash, forKey: "crashFatal")
        }

        return result
    }
}
