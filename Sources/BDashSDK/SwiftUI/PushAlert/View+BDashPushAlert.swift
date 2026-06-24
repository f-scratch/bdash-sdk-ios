import SwiftUI

public extension View {
    /// フォアグラウンド Push 通知アラートの表示を有効にする。
    ///
    /// `controller.present(userInfo:)` を呼ぶと、既存の UIKit アラート
    /// （`BDashAlertViewController` / `BDashDoubleButtonAlertViewController`）が
    /// このビューの上に `.overCurrentContext` で表示される。
    ///
    /// - Parameter controller: アラートの表示状態を管理する `BDashPushAlertController`。
    func bDashPushAlert(controller: BDashPushAlertController) -> some View {
        modifier(BDashPushAlertModifier(controller: controller))
    }
}

private struct BDashPushAlertModifier: ViewModifier {
    @ObservedObject var controller: BDashPushAlertController

    func body(content: Content) -> some View {
        content.background(
            BDashPushAlertHostRepresentable(
                isPresented: $controller.isPresented,
                contents: controller.contents,
                lateImage: controller.lateImage
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        )
    }
}
