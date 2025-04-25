//
//  TextfieldTableViewCell.swift
//  AttentiveExample
//
//  Created by Adela Gao on 4/21/25.
//

import UIKit

// MARK: - TextFieldCell.swift

class TextfieldTableViewCell: UITableViewCell {
  static let reuseID = "TextfieldTableViewCell"

  let textField: UITextField = {
    let textfield = UITextField()
    textfield.translatesAutoresizingMaskIntoConstraints = false
    textfield.placeholder = ""
    // Match “Apply Coupon” styling
    textfield.font = UIFont(name: "DegularDisplay-Regular", size: 16)
    textfield.layer.borderColor = UIColor.black.cgColor
    textfield.layer.borderWidth = 1
    textfield.layer.cornerRadius = 8
    // fixed height
    textfield.heightAnchor.constraint(equalToConstant: 46).isActive = true
    // left padding
    textfield.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
    textfield.leftViewMode = .always
    return textfield
  }()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  required init?(coder: NSCoder) { fatalError() }

  private func setup() {
    contentView.addSubview(textField)
    NSLayoutConstraint.activate([
      textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
      textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
    ])
    selectionStyle = .none
  }

  func configure(placeholder: String) {
    textField.placeholder = placeholder
  }
}
