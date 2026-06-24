import Foundation

/// スクリーンビュービルダー
@objcMembers
open class ScreenViewBuilder: BaseBuilder {

    /**
     コンストラクタ
     - returns: なし
     */
    public override init() {
        super.init()
        super.internalType = BDashConst.kInternalTypeScreen
        super.eventDateTime = TrackUtil().generateEventDate()
    }

    /**
     builderの情報をmapオブジェクトに変換
     - returns: Dictionaryオブジェクト（json変換前）
     */
    override open func mapping2dictionary() -> NSMutableDictionary {
        let result = super.mapping2dictionary()
        return result
    }
}
