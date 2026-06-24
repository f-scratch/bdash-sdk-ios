import SwiftUI

public extension View {
    /// オーバーレイ型 Web 接客の表示を有効にする。
    ///
    /// `controller.show(report:)` を呼ぶと、`BDashWebReception.showMessage` が
    /// このビューの上にポップアップを表示する。スキーム処理・閉じる操作は Core 側に委譲される。
    ///
    /// - Parameter controller: 表示状態を管理する `BDashWebReceptionOverlayController`。
    func bDashWebReceptionOverlay(controller: BDashWebReceptionOverlayController) -> some View {
        modifier(BDashWebReceptionOverlayModifier(controller: controller))
    }
}

private struct BDashWebReceptionOverlayModifier: ViewModifier {
    @ObservedObject var controller: BDashWebReceptionOverlayController

    func body(content: Content) -> some View {
        content.overlay(
            BDashWebReceptionOverlayHost(
                isPresented: $controller.isPresented,
                report: controller.report,
                reception: controller.reception,
                allowClick: controller.allowClick,
                sizeUnit: controller.sizeUnit
            )
            .allowsHitTesting(controller.isPresented)
            .ignoresSafeArea()
        )
    }
}
