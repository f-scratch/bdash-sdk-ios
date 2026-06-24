import SwiftUI
import UIKit

/// 既存の UIKit アラート（`BDashAlertViewController` / `BDashDoubleButtonAlertViewController`）を
/// SwiftUI のビュー階層から present するためのホスト。
///
/// アラート UI 自体は UIKit 実装をそのまま使い、SwiftUI 側で再描画しない。
/// 透明なホスト VC を 0pt で SwiftUI ツリーに埋め、そこから `.overCurrentContext` の
/// アラート VC を present する。
struct BDashPushAlertHostRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let contents: BDashAlertViewContents?
    /// 非同期取得したフォールバック画像。表示中アラートへ後差し込みする。
    let lateImage: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        return host
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        let coordinator = context.coordinator

        // ユーザーがアラート側のボタンで自発的に閉じた場合、presented が nil に戻る。
        // その状態を検知して isPresented を false に同期する。
        if coordinator.isShowingAlert, host.presentedViewController == nil {
            coordinator.isShowingAlert = false
            if isPresented {
                DispatchQueue.main.async { self.isPresented = false }
            }
            return
        }

        if isPresented, !coordinator.isShowingAlert, let contents = contents {
            let alert = Self.makeAlertViewController(from: contents)
            coordinator.isShowingAlert = true
            coordinator.presentedAlert = alert
            host.present(alert, animated: true)
        } else if !isPresented, coordinator.isShowingAlert {
            coordinator.isShowingAlert = false
            coordinator.presentedAlert = nil
            host.dismiss(animated: true)
        }

        // 非同期取得したフォールバック画像が届いたら表示中アラートへ後差し込みする
        if let lateImage = lateImage, let alert = coordinator.presentedAlert {
            alert.applyLateImage(lateImage)
        }
    }

    /// `alertType` に応じて UIKit のアラート VC を生成する（UIKit 側の分岐をそのまま踏襲）。
    private static func makeAlertViewController(from contents: BDashAlertViewContents) -> BDashAlertViewController {
        switch contents.alertType {
        case .BDashDoubleButtonAlert:
            return BDashDoubleButtonAlertViewController(from: contents)
        case .BDashAlert:
            return BDashAlertViewController(from: contents)
        }
    }

    final class Coordinator {
        @Binding var isPresented: Bool
        var isShowingAlert: Bool = false
        /// 表示中のアラート VC（フォールバック画像の後差し込み用）。
        weak var presentedAlert: BDashAlertViewController?

        init(isPresented: Binding<Bool>) {
            self._isPresented = isPresented
        }
    }
}
