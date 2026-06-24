import UIKit

@available(iOS 9.0, *)
public class BDashAlertViewController: UIViewController {

    var baseView = UIView()
    var contentView = UIView()
    var scrollView = UIScrollView()
    var separatorView = UIView()
    var firstButton = UIButton()
    var contentStackView = UIStackView()
    var imageView = UIImageView()
    var titleLabel = UILabel()
    var titleLabelView = UIView()
    var bodyLabel = UILabel()
    var bodyLabelView = UIView()
    
    /// 通知アラートの表示内容コンテンツ
    var alertContents = BDashAlertViewContents()
    
    /// 通知内容テキストの余白設定
    lazy var spacing: CGFloat = {
        return (alertContents.title ?? "").isEmpty || (alertContents.body ?? "").isEmpty ? 16.0 : 8.0
    }()
    
    /// ボタンのフォント色
    let buttonFontColor: UIColor = {
        let spareColor = UIColor.init(red: 0.0, green: 122/225, blue: 1.0, alpha: 1.0)
        if #available(iOS 13.0, *) {
            // ダークモード対応バージョンのため動的指定
            return UIColor.value(forKey: "systemBlueColor") as? UIColor ?? spareColor
        } else {
            return spareColor
        }
    }()
    
    /// 通知アラート表示の背景色
    let alertBackgroundColor: UIColor = {
        if #available(iOS 13.0, *) {
            // ダークモード対応バージョンのため動的指定
            return UIColor.value(forKey: "systemBackgroundColor") as? UIColor ?? .white
        } else {
            return .white
        }
    }()
    
    public init(from alertContents: BDashAlertViewContents) {
        super.init(nibName: nil, bundle: nil)
        self.alertContents = alertContents
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            view.frame = keyWindow.bounds
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.modalTransitionStyle = .crossDissolve
        self.modalPresentationStyle = .overCurrentContext
        showAlertView()
    }
    
    func showAlertView() {
        view.addSubview(baseView)
        let alpha = alertContents.isWithOverray ? 0.3 : 0.0
        baseView.backgroundColor = UIColor.black.withAlphaComponent(alpha)
        baseView.isOpaque = true
        baseView.addSubview(contentView)
        baseView.translatesAutoresizingMaskIntoConstraints = false
        baseView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        baseView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        baseView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        baseView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.backgroundColor = alertBackgroundColor
        contentView.layer.cornerRadius = 10.0
        contentView.layer.masksToBounds = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.centerXAnchor.constraint(equalTo: baseView.centerXAnchor).isActive = true
        contentView.centerYAnchor.constraint(equalTo: baseView.centerYAnchor).isActive = true
        contentView.widthAnchor.constraint(equalToConstant: 270).isActive = true
        if #available(iOS 11, *) {
            let guide = view.safeAreaLayoutGuide
            contentView.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor).isActive = true
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor).isActive = true
        } else {
            contentView.topAnchor.constraint(greaterThanOrEqualTo: baseView.topAnchor).isActive = true
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: baseView.bottomAnchor).isActive = true
        }
        prepareTextElements()
        prepareButton()
        prepareSeparatorView()
        contentView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: separatorView.topAnchor).isActive = true
        scrollView.addSubview(contentStackView)
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.distribution = .equalSpacing
        contentStackView.spacing = 0.0
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor).isActive = true
        contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        let contentStackViewHeightConstraint = contentStackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        contentStackViewHeightConstraint.priority = UILayoutPriority(rawValue: 200)
        contentStackViewHeightConstraint.isActive = true
        
        if let image = alertContents.image {
            placeImage(image)
        }
    }

    /// 画像を `contentStackView` の所定位置に配置する（初期表示・後差し込み共通）。
    private func placeImage(_ image: UIImage) {
        // 既に配置済みなら二重挿入しない
        guard imageView.superview == nil else { return }
        let index = alertContents.imagePosition == .bottom ? 2 : 0
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let multiplier: CGFloat = {
            let width = image.size.width
            let height = image.size.height
            return (width * height > 0) && (height / width < 1) ? height / width : 1
        }()
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: multiplier).isActive = true
        // imagePosition == .bottom の index 2 が現在の arrangedSubviews 数を超える場合は末尾に追加する
        let insertIndex = min(index, contentStackView.arrangedSubviews.count)
        contentStackView.insertArrangedSubview(imageView, at: insertIndex)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = image
    }

    /// 非同期取得した画像を表示中のアラートへ反映する（フォアグラウンド・フォールバック用）。
    func applyLateImage(_ image: UIImage) {
        // _sharedMediaPath 経由で既に画像がある場合は何もしない
        guard alertContents.image == nil else { return }
        alertContents.image = image
        // viewDidLoad 前（showAlertView 未実行）の場合は showAlertView 側で配置されるためスキップ
        guard isViewLoaded else { return }
        placeImage(image)
    }
    
    func prepareTextElements() {
        if let title = alertContents.title, !(title.isEmpty) {
            contentStackView.addArrangedSubview(titleLabelView)
            titleLabelView.addSubview(titleLabel)
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 0
            titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
            titleLabel.text = title
            titleLabelView.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.topAnchor.constraint(equalTo:titleLabelView.topAnchor, constant: spacing).isActive = true
            titleLabel.leadingAnchor.constraint(equalTo: titleLabelView.leadingAnchor, constant: spacing).isActive = true
            titleLabel.trailingAnchor.constraint(equalTo: titleLabelView.trailingAnchor, constant: -spacing).isActive = true
            titleLabel.bottomAnchor.constraint(equalTo: titleLabelView.bottomAnchor, constant: -spacing).isActive = true
        }
        if let body = alertContents.body, !(body.isEmpty) {
            contentStackView.addArrangedSubview(bodyLabelView)
            bodyLabelView.addSubview(bodyLabel)
            bodyLabel.textAlignment = .center
            bodyLabel.numberOfLines = 0
            bodyLabel.font = UIFont.systemFont(ofSize: 14)
            bodyLabel.text = body
            bodyLabelView.translatesAutoresizingMaskIntoConstraints = false
            bodyLabel.translatesAutoresizingMaskIntoConstraints = false
            bodyLabel.topAnchor.constraint(equalTo:bodyLabelView.topAnchor, constant: spacing).isActive = true
            bodyLabel.leadingAnchor.constraint(equalTo: bodyLabelView.leadingAnchor, constant: spacing).isActive = true
            bodyLabel.trailingAnchor.constraint(equalTo: bodyLabelView.trailingAnchor, constant: -spacing).isActive = true
            bodyLabel.bottomAnchor.constraint(equalTo: bodyLabelView.bottomAnchor, constant: -spacing).isActive = true
        }
    }
    
    func prepareButton() {
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
        firstButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        firstButton.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 1.0).isActive = true
    }
    
    func prepareSeparatorView() {
        contentView.addSubview(separatorView)
        separatorView.backgroundColor = .lightGray
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        separatorView.bottomAnchor.constraint(equalTo: firstButton.topAnchor).isActive = true
        separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
    }
    
    @objc func firstButtonTapped(_ button: UIButton) {
        printLogWhenButtonTapped(at: 0)
        self.dismiss(animated: true)
    }
    
    func printLogWhenButtonTapped(at index: Int) {
        var path = ""
        let notificationParam: String? = {
            if alertContents.alertButtons.indices.contains(index) {
                path = "data/buttons/"
                return alertContents.alertButtons[index].notificationParam
            } else if let contentsParam = alertContents.notificationParam {
                path = "data/"
                return contentsParam
            } else {
                return nil
            }
        }()
        let layoutStr: String = {
            if alertContents.alertButtons.indices.contains(index),
               let layout = alertContents.alertButtons[index].layout {
                return layout.getString()
            }
            return "(no layout assign)"
        }()
        BDashLogger.debug("tapped \(layoutStr) Alert Button")
        if var param = notificationParam {
            BDashLogger.debug("exists \(path) notification_param in payload")
            param = param.isEmpty ? "(empty)" : param
            BDashLogger.debug("notification_param: \(String(describing: param))")
        } else {
            BDashLogger.debug("notification_param is nil, no notif)ication_param in payload")
        }
    }
}
