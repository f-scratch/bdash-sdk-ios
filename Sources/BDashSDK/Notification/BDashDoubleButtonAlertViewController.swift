import UIKit

@available(iOS 9.0, *)
public class BDashDoubleButtonAlertViewController: BDashAlertViewController {
 
    var subSeparatorView = UIView()
    var secondButton = UIButton()
    
    override func prepareButton() {
        contentView.addSubview(firstButton)
        var firstButtonLabel = "OK"
        if alertContents.alertButtons.indices.contains(0) {
            if let label = alertContents.alertButtons[0].label, !label.isEmpty {
                firstButtonLabel = label
            }
        }
        firstButton.setTitle(firstButtonLabel, for: .normal)
        firstButton.setTitleColor(buttonFontColor, for: .normal)
        firstButton.setTitleColor(buttonFontColor.withAlphaComponent(0.3), for: .highlighted)
        firstButton.addTarget(self, action: #selector(self.firstButtonTapped), for: .touchUpInside)
        firstButton.translatesAutoresizingMaskIntoConstraints = false
        firstButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        firstButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        if alertContents.alertButtons.indices.contains(0) {
            if alertContents.alertButtons[0].layout == .left {
                firstButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            } else if alertContents.alertButtons[0].layout == .right {
                firstButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            } else {
                firstButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            }
        } else {
            firstButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        }
        firstButton.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.5).isActive = true
        contentView.addSubview(secondButton)
        var secondButtonLabel = "閉じる"
        if alertContents.alertButtons.indices.contains(1) {
            if let label = alertContents.alertButtons[1].label, !label.isEmpty {
                secondButtonLabel = label
            }
        }
        secondButton.setTitle(secondButtonLabel, for: .normal)
        secondButton.setTitleColor(buttonFontColor, for: .normal)
        secondButton.setTitleColor(buttonFontColor.withAlphaComponent(0.3), for: .highlighted)
        secondButton.addTarget(self, action: #selector(self.secondButtonTapped), for: .touchUpInside)
        secondButton.translatesAutoresizingMaskIntoConstraints = false
        secondButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        secondButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        if alertContents.alertButtons.indices.contains(1) {
            if alertContents.alertButtons[1].layout == .left {
                secondButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            } else if alertContents.alertButtons[1].layout == .right {
                secondButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            } else {
                secondButton.trailingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            }
        } else {
            secondButton.trailingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        }
        secondButton.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.5).isActive = true
    }
    
    override func prepareSeparatorView() {
        contentView.addSubview(separatorView)
        separatorView.backgroundColor = .lightGray
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        separatorView.bottomAnchor.constraint(equalTo: firstButton.topAnchor).isActive = true
        separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        contentView.addSubview(subSeparatorView)
        subSeparatorView.backgroundColor = .lightGray
        subSeparatorView.translatesAutoresizingMaskIntoConstraints = false
        subSeparatorView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        subSeparatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        subSeparatorView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        subSeparatorView.widthAnchor.constraint(equalToConstant: 1).isActive = true
    }
    
    @objc override func firstButtonTapped(_ button: UIButton) {
        printLogWhenButtonTapped(at: 0)
        buttonTappedProcess(notificationParam: getNotificationParam(at: 0))
    }
    
    @objc func secondButtonTapped(_ button: UIButton) {
        printLogWhenButtonTapped(at: 1)
        buttonTappedProcess(notificationParam: getNotificationParam(at: 1))
    }
    
    /// アラートボタンタップ後の処理
    /// - Parameter notificationParam: 通知パラメータ
    private func buttonTappedProcess(notificationParam: String) {
        self.dismiss(animated: true)
    }
    
    /// 通知パラメータ取得
    /// - Parameter index: インデックス
    /// - Returns: 文字列の通知パラメータ
    private func getNotificationParam(at index: Int) -> String {
        guard let notificationParam: String = {
            if alertContents.alertButtons.indices.contains(index) {
                return alertContents.alertButtons[index].notificationParam
            } else if let contentsParam = alertContents.notificationParam {
                return contentsParam
            } else {
                return nil
            }
        }() else {
            return ""
        }
        return notificationParam
    }
}
