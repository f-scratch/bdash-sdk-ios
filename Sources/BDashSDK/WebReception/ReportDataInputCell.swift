import UIKit

class ReportDataInputCell: UITableViewCell {
    public static let reuseId = "ReportDataInputCell"
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var colonLabel: UILabel!
    
    //MARK: - init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    //MARK: - public func
    
    func setup(title: String, inputedText: String?) {
        self.titleLabel.text = title
        self.inputTextField.text = inputedText
    }
}
