//
//  CartTableViewCell.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/5/25.
//

import UIKit
import ATTNSDKFramework

protocol CartTableViewCellDelegate: AnyObject {
    func didTapDeleteButton(in cell: CartTableViewCell)
}

class CartTableViewCell: UITableViewCell {

  weak var delegate: CartTableViewCellDelegate?

  private let productImageView = UIImageView()
  private let productNameLabel = UILabel()
  private let productQuantityLabel = UILabel()
  private let productPriceLabel = UILabel()
  private let deleteButton = UIButton(type: .system)

  var deleteAction: (() -> Void)?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    productImageView.translatesAutoresizingMaskIntoConstraints = false
    productImageView.contentMode = .scaleAspectFit
    productImageView.layer.cornerRadius = 8
    productImageView.layer.masksToBounds = true
    productImageView.widthAnchor.constraint(equalToConstant: 80).isActive = true
    productImageView.heightAnchor.constraint(equalToConstant: 80).isActive = true

    productNameLabel.font = UIFont.boldSystemFont(ofSize: 16)
    productQuantityLabel.font = UIFont.systemFont(ofSize: 14)
    productPriceLabel.font = UIFont.systemFont(ofSize: 14)
    productPriceLabel.textColor = .systemGreen

    let infoStackView = UIStackView(arrangedSubviews: [productNameLabel, productQuantityLabel, productPriceLabel])
    infoStackView.axis = .vertical
    infoStackView.spacing = 4
    infoStackView.translatesAutoresizingMaskIntoConstraints = false

    deleteButton.setTitle("Delete", for: .normal)
    deleteButton.setTitleColor(.red, for: .normal)
    deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
    deleteButton.translatesAutoresizingMaskIntoConstraints = false

    let stackView = UIStackView(arrangedSubviews: [productImageView, infoStackView, deleteButton])
    stackView.axis = .horizontal
    stackView.spacing = 10
    stackView.alignment = .center
    stackView.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
      stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
      stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
      stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
    ])
  }

  @objc private func deleteTapped() {
    delegate?.didTapDeleteButton(in: self)
  }

  func configure(with product: ATTNItem) {
    productNameLabel.text = product.name ?? "Unknown Product"
    productPriceLabel.text = formatPrice(product.price)

    if let imageUrl = product.productImage, let url = URL(string: imageUrl) {
      loadImage(from: url)
    } else {
      productImageView.image = UIImage(systemName: "photo") // Placeholder
    }
  }
  private func formatPrice(_ price: ATTNPrice) -> String {
    return "\(price.currency) \(price.price.stringValue)"
  }

  private func loadImage(from url: URL) {
    DispatchQueue.global().async {
      if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
        DispatchQueue.main.async {
          self.productImageView.image = image
        }
      }
    }
  }
}
