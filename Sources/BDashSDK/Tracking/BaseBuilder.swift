import Foundation

/// Builder基底クラス
/// 内部タイプなど子となるビルダークラスの共通属性を持つ。
/// ビルダークラスは必ずこのクラスを継承する。
@objcMembers
open class BaseBuilder: NSObject {
    ///内部タイプ
    var internalType:String!
    ///イベント(ログ)時刻
    var eventDateTime:String!
    ///スクリーン名
    var screenName:String!
    ///ログインユーザーID
    var loginUserId:String!
    ///リレーショナルキー
    var relationalKey:String!
    ///リレーショナルバリュー
    var relationalValue:String!
    ///ユーザー情報:アプリ開発者が定義したユーザー情報のキーバリュー値
    var userMap:NSDictionary!
    ///起動元:bootType
    var bootType:String!
    ///起動値:bootValue
    var bootValue:String!

    /**
     コンストラクタ
     */
    public override init() {
        super.init()
    }

    /**
     builderの情報をmapオブジェクトに変換　＊継承クラスはこのメソッドをオーバーライドする。
     - returns: Dictionaryオブジェクト（json変換前）
     */
    open func mapping2dictionary()-> NSMutableDictionary {
        let result = NSMutableDictionary()
        if self.internalType != nil && "" != self.internalType {
            result.setValue(self.internalType, forKey: "internalType")
        }
        if self.eventDateTime != nil && "" != self.eventDateTime {
            result.setValue(self.eventDateTime, forKey: "eventDateTime")
        }
        if self.screenName != nil {
            result.setValue(self.screenName, forKey: "screenName")
        }
        if self.relationalKey != nil {
            result.setValue(self.relationalKey, forKey: "relationalKey")
        }
        if self.relationalValue != nil {
            result.setValue(self.relationalValue, forKey: "relationalValue")
        }
        if self.loginUserId != nil {
            result.setValue(self.loginUserId, forKey: "loginUserId")
        }
        if self.bootType != nil  {
            result.setValue(self.bootType, forKey: "bootType")
        }
        if self.bootType != nil {
            result.setValue(self.bootValue, forKey: "bootValue")
        }
        if self.userMap != nil {
            result.setValue(self.userMap, forKey: "userMap")
        }
        return result
    }
}
