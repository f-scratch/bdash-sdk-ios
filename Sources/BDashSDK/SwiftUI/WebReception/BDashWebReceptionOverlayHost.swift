import SwiftUI
import UIKit

/// オーバーレイ型 Web 接客を SwiftUI のビュー階層に表示するためのホスト。
///
/// `BDashWebReception.showMessage(report:onView:)` がポップアップ生成・WebView 制御・
/// スキーム処理をすべて内部で完結するため、ここでは透明なホスト UIView を提供し、
/// そこに対して showMessage / closeMessage を呼ぶだけ。
struct BDashWebReceptionOverlayHost: UIViewRepresentable {
    @Binding var isPresented: Bool
    let report: BDashReport?
    let reception: BDashWebReception
    /// 背面タップの透過可否（配信 JSON の `allowClick`）。ホストの hitTest 挙動を切り替える。
    let allowClick: Bool
    /// ポップアップのサイズ単位（`"auto"` / `"px"` / `"vw"`）。`showMessage` にそのまま渡す。
    let sizeUnit: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = PassthroughHostView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator

        // allowClick が確定するたびにホストへ反映する。
        (uiView as? PassthroughHostView)?.allowClick = allowClick

        if isPresented, !coordinator.isShowing, let report = report {
            coordinator.isShowing = true
            _ = reception.showMessage(report: report, onView: uiView, sizeUnit: sizeUnit)
        } else if !isPresented, coordinator.isShowing {
            coordinator.isShowing = false
            reception.closeMessage()
        }
    }

    final class Coordinator {
        var isShowing: Bool = false
    }
}

/// オーバーレイ型 Web 接客を載せる透明ホスト。
///
/// `UIView` 既定の `hitTest` は、サブビューが誰も取らず点が自分の bounds 内にあるとき自分自身を返す
/// （背景が `.clear` でも変わらない）。フルスクリーンのホストではこれが背面タップを飲み込み、
/// SwiftUI 配下のアプリ UI へ届かなくなる。`allowClick==true` のときヒットが自分自身（背面の透明領域）
/// なら `nil` を返して透過させ、UIKit 版 `TransmissionView` と同じ挙動にする。
/// `allowClick==false`（モーダル）は自分自身を返して背面タップを遮断する。
final class PassthroughHostView: UIView {
    var allowClick: Bool = true

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if allowClick, hit === self {
            return nil
        }
        return hit
    }
}
