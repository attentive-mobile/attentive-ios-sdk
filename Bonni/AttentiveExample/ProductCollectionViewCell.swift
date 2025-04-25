//
//  ProductCollectionViewCell.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/5/25.
//

import UIKit
import ATTNSDKFramework

protocol ProductCollectionViewCellDelegate: AnyObject {
  func didTapAddToCartButton(product: ATTNItem)
  func didTapProductImage(product: ATTNItem)
}

class ProductCollectionViewCell: UICollectionViewCell {

  // MARK: - Delegate & Model

  weak var delegate: ProductCollectionViewCellDelegate?
  private var product: ATTNItem?

  // MARK: - UI Components

  /// Main vertical stack view (image + labels)
  private let verticalStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.distribution = .equalSpacing
    stackView.spacing = 8
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()

  /// Product image view - very prominent
  private let productImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    imageView.clipsToBounds = true
    imageView.isUserInteractionEnabled = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.layer.cornerRadius = 16
    return imageView
  }()

  /// Stack view for labels (name + price)
  private let labelsStackView: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.alignment = .leading
    stack.spacing = 4
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  /// Main label - product name
  private let productNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont(name: "DegularDisplay-Regular", size: 16)
    label.textColor = .black
    label.textAlignment = .left
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  /// Subtitle label - product price
  private let productPriceLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14)
    label.textColor = .gray
    label.textAlignment = .left
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  /// Add-to-cart button overlay on image with white circular background
  private let addToCartButton: UIButton = {
    let button = UIButton(type: .system)
    let cartImage = UIImage(named: "Shopping cart")?
      .withRenderingMode(.alwaysTemplate)
    button.setImage(cartImage, for: .normal)
    button.tintColor = .black
    button.backgroundColor = .white
    button.layer.cornerRadius = 15  // half of 30 to stay perfectly round
    button.layer.masksToBounds = true
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupUI()
    addImageTapRecognizer()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupUI()
    addImageTapRecognizer()
  }

  // MARK: - Layout

  private func setupUI() {
    contentView.layer.masksToBounds = true

    contentView.addSubview(verticalStackView)

    verticalStackView.addArrangedSubview(productImageView)
    verticalStackView.addArrangedSubview(labelsStackView)

    labelsStackView.addArrangedSubview(productNameLabel)
    labelsStackView.addArrangedSubview(productPriceLabel)

    productImageView.addSubview(addToCartButton)

    NSLayoutConstraint.activate([
      // Pin stack view to cell edges
      verticalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
      verticalStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
      verticalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
      verticalStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),

      // Make image view fill ~80% of cell height
      productImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),

      // Cart button size & position
      addToCartButton.widthAnchor.constraint(equalToConstant: 30),
      addToCartButton.heightAnchor.constraint(equalToConstant: 30),
      addToCartButton.trailingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: -8),
      addToCartButton.bottomAnchor.constraint(equalTo: productImageView.bottomAnchor, constant: -8)
    ])
  }

  // MARK: - Configuration

  func configure(with product: ATTNItem) {
    self.product = product
    productNameLabel.text = product.name ?? "Unknown Product"
    productPriceLabel.text = {
      let price = product.price
      return "\(price.currency) \(price.price.stringValue)"
    }()

    productImageView.image = UIImage(named: product.name ?? "Protective Superscreen")

    addToCartButton.addTarget(self, action: #selector(addToCartTapped), for: .touchUpInside)
  }

  // MARK: - Actions

  private func addImageTapRecognizer() {
    let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
    productImageView.addGestureRecognizer(tap)
  }

  @objc private func imageTapped() {
    guard let product = product else { return }
    delegate?.didTapProductImage(product: product)
  }

  @objc private func addToCartTapped() {
    guard let product = product else { return }
    delegate?.didTapAddToCartButton(product: product)
  }
}
