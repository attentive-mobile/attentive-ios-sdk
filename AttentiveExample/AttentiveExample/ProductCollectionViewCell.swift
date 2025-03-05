//
//  ProductCollectionViewCell.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/5/25.
//

import UIKit
import ATTNSDKFramework

class ProductCollectionViewCell: UICollectionViewCell {
  
  private let verticalStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.distribution = .equalSpacing
    stackView.spacing = 8
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()
  
  private let productImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()
  
  private let productNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private let productPriceLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textColor = .darkGray
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private let addToCartButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Add To Cart", for: .normal)
    button.backgroundColor = .systemBlue
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 5
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupUI()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupUI() {
    contentView.addSubview(verticalStackView)
    
    verticalStackView.addArrangedSubview(productImageView)
    verticalStackView.addArrangedSubview(productNameLabel)
    verticalStackView.addArrangedSubview(productPriceLabel)
    verticalStackView.addArrangedSubview(addToCartButton)
    
    NSLayoutConstraint.activate([
      verticalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
      verticalStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
      verticalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
      verticalStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
    ])
    
    NSLayoutConstraint.activate([
      productImageView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.7),
      addToCartButton.heightAnchor.constraint(equalToConstant: 30)
    ])
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
