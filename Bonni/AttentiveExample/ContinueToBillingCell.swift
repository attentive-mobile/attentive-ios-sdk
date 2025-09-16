//
//  PlaceOrderTableViewCell.swift
//  AttentiveExample
//
//  Created by Adela Gao on 9/10/25.
//

import UIKit

protocol ContinueToBillingCellDelegate: AnyObject {
  func didTapContinueToBillingCell(_ cell: ContinueToBillingCell)
}

class ContinueToBillingCell: UITableViewCell {
  static let reuseID = "ContinueToBillingCell"
  weak var delegate: ContinueToBillingCellDelegate?

  private let button: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Continue", for: .normal)
    button.titleLabel?.font = UIFont(name: "DegularDisplay-Regular", size: 16)
    button.backgroundColor = .black
    button.setTitleColor(.white, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
      button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
      button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
      button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
      button.heightAnchor.constraint(equalToConstant: 50)
    ])
    button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    selectionStyle = .none
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  @objc private func buttonTapped() {
    delegate?.didTapContinueToBillingCell(self)
  }
}
