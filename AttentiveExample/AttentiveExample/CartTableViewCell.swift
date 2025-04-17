//
//  CartTableViewCell.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/5/25.
//

import UIKit
import ATTNSDKFramework

protocol CartTableViewCellDelegate: AnyObject {
  func didTapIncrease(in cell: CartTableViewCell)
  func didTapDecrease(in cell: CartTableViewCell)
}

class CartTableViewCell: UITableViewCell {
  
  weak var delegate: CartTableViewCellDelegate?
  
  private let productImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.layer.cornerRadius = 16
    return imageView
  }()
  
  /// Main label for product name
  private let productNameLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = UIFont(name: "DegularDisplay-Regular", size: 16)
    label.textColor = .black
    return label
  }()
  
  /// Subtitle label for product type
  private let productTypeLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = UIFont.systemFont(ofSize: 14)
    label.textColor = .gray
    label.text = "Daily Moisturizer"
    return label
  }()
  
  /// Price label, aligned bottom-right
  private let productPriceLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = UIFont(name: "DegularDisplay-Regular", size: 16)
    label.textColor = .gray
    label.textAlignment = .right
    return label
  }()
  
  /// Quantity controls
  private let minusButton: UIButton = {
    let btn = UIButton(type: .system)
    btn.setTitle("–", for: .normal)
    btn.tintColor = .black
    btn.backgroundColor = .lightGray
    btn.layer.cornerRadius = 8
    btn.translatesAutoresizingMaskIntoConstraints = false
    return btn
  }()
  
  private let quantityLabel: UILabel = {
    let lbl = UILabel()
    lbl.text = "1"
    lbl.textAlignment = .center
    lbl.font = UIFont.systemFont(ofSize: 12)
    lbl.translatesAutoresizingMaskIntoConstraints = false
    return lbl
  }()
  
  private let plusButton: UIButton = {
    let btn = UIButton(type: .system)
    btn.setTitle("+", for: .normal)
    btn.tintColor = .black
    btn.backgroundColor = .lightGray
    btn.layer.cornerRadius = 8
    btn.translatesAutoresizingMaskIntoConstraints = false
    return btn
  }()
  
  var deleteAction: (() -> Void)?
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupViews()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupViews() {
    contentView.addSubview(productImageView)
    contentView.addSubview(productNameLabel)
    contentView.addSubview(productTypeLabel)
    contentView.addSubview(productPriceLabel)
    
    
    NSLayoutConstraint.activate([
      // Product Image
      productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
      productImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      productImageView.widthAnchor.constraint(equalToConstant: 80),
      productImageView.heightAnchor.constraint(equalTo: productImageView.widthAnchor),
      
      // Product Name Label
      productNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
      productNameLabel.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 10),
      
      // Product Type Label
      productTypeLabel.topAnchor.constraint(equalTo: productNameLabel.bottomAnchor, constant: 4),
      productTypeLabel.leadingAnchor.constraint(equalTo: productNameLabel.leadingAnchor),
      
      
      // Price Label
      productPriceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
      productPriceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
    ])
    
    // add quantity controls
    contentView.addSubview(minusButton)
    contentView.addSubview(quantityLabel)
    contentView.addSubview(plusButton)
    minusButton.addTarget(self, action: #selector(decreaseTapped), for: .touchUpInside)
    plusButton.addTarget(self, action: #selector(increaseTapped), for: .touchUpInside)
    
    // constraints: bottom aligned to imageView, leading to name
    NSLayoutConstraint.activate([
      minusButton.leadingAnchor.constraint(equalTo: productNameLabel.leadingAnchor),
      minusButton.bottomAnchor.constraint(equalTo: productImageView.bottomAnchor),
      minusButton.widthAnchor.constraint(equalToConstant: 16),
      minusButton.heightAnchor.constraint(equalToConstant: 16),
      
      quantityLabel.leadingAnchor.constraint(equalTo: minusButton.trailingAnchor, constant: 8),
      quantityLabel.centerYAnchor.constraint(equalTo: minusButton.centerYAnchor),
      quantityLabel.widthAnchor.constraint(equalToConstant: 16),
      quantityLabel.heightAnchor.constraint(equalToConstant: 16),
      
      plusButton.leadingAnchor.constraint(equalTo: quantityLabel.trailingAnchor, constant: 8),
      plusButton.centerYAnchor.constraint(equalTo: quantityLabel.centerYAnchor),
      plusButton.widthAnchor.constraint(equalToConstant: 16),
      plusButton.heightAnchor.constraint(equalToConstant: 16)
    ])
  }
  
  func configure(with product: ATTNItem, quantity: Int) {
    productNameLabel.text = product.name ?? "Unknown Product"
    productPriceLabel.text = formatPrice(product.price)
    productImageView.image = UIImage(named: product.name ?? "Protective Superscreen")
    quantityLabel.text = "\(quantity)"
  }
  private func formatPrice(_ price: ATTNPrice) -> String {
    return "\(price.currency) \(price.price.stringValue)"
  }
  
  @objc private func increaseTapped() {
    delegate?.didTapIncrease(in: self)
  }
  
  @objc private func decreaseTapped() {
    delegate?.didTapDecrease(in: self)
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
