//
//  ProductDetailViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/14/25.
//
import UIKit
import ATTNSDKFramework

protocol ProductDetailViewControllerDelegate: AnyObject {
    func productDetailViewController(_ controller: ProductDetailViewController, didAddToCart product: ATTNItem)
}

class ProductDetailViewController: UIViewController {

  // MARK: - Properties

  private let product: ATTNItem
  weak var delegate: ProductDetailViewControllerDelegate?

  // MARK: - UI Components

  private let productImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.isUserInteractionEnabled = true
    return imageView
  }()

  private let productNameLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.boldSystemFont(ofSize: 22)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let addToCartButton: UIButton = {
          let button = UIButton(type: .system)
          button.setTitle("Add to Cart (Legacy)", for: .normal)
          button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
          button.backgroundColor = .systemBlue
          button.setTitleColor(.white, for: .normal)
          button.layer.cornerRadius = 8
          button.translatesAutoresizingMaskIntoConstraints = false
          return button
      }()

  private let addToCartV2Button: UIButton = {
          let button = UIButton(type: .system)
          button.setTitle("Add to Cart (V2 - New Format)", for: .normal)
          button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
          button.backgroundColor = .systemGreen
          button.setTitleColor(.white, for: .normal)
          button.layer.cornerRadius = 8
          button.translatesAutoresizingMaskIntoConstraints = false
          return button
      }()

  // MARK: - Initialization

  init(product: ATTNItem) {
    self.product = product
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    setupUI()
    configureProduct()
  }

  // MARK: - Setup UI

  private func setupUI() {
    view.addSubview(productImageView)
    view.addSubview(productNameLabel)
    view.addSubview(addToCartButton)
    view.addSubview(addToCartV2Button)

    addToCartButton.addTarget(self, action: #selector(addToCartTapped), for: .touchUpInside)
    addToCartV2Button.addTarget(self, action: #selector(addToCartV2Tapped), for: .touchUpInside)

    NSLayoutConstraint.activate([
      productImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      productImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      productImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      productImageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),

      productNameLabel.topAnchor.constraint(equalTo: productImageView.bottomAnchor, constant: 20),
      productNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      productNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      addToCartButton.topAnchor.constraint(equalTo: productNameLabel.bottomAnchor, constant: 20),
      addToCartButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      addToCartButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      addToCartButton.heightAnchor.constraint(equalToConstant: 50),

      addToCartV2Button.topAnchor.constraint(equalTo: addToCartButton.bottomAnchor, constant: 10),
      addToCartV2Button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      addToCartV2Button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      addToCartV2Button.heightAnchor.constraint(equalToConstant: 50),
    ])
  }

  private func configureProduct() {
    productNameLabel.text = product.name ?? "Unknown Product"
    if let imageUrl = product.productImage, let url = URL(string: imageUrl) {
      loadImage(from: url)
    } else {
      productImageView.image = UIImage(systemName: "photo")
    }
  }

  private func loadImage(from url: URL) {
    DispatchQueue.global().async {
      if let data = try? Data(contentsOf: url),
         let image = UIImage(data: data) {
        DispatchQueue.main.async {
          self.productImageView.image = image
        }
      }
    }
  }

  private func recordProductViewEvent() {
    let productViewEvent : ATTNProductViewEvent = ATTNProductViewEvent(items: [product])
    ATTNEventTracker.sharedInstance()?.record(event: productViewEvent)
    showToast(with: "Product View event sent")
  }

  // MARK: - Actions
  @objc private func addToCartTapped() {
    delegate?.productDetailViewController(self, didAddToCart: product)
  }

  @objc private func addToCartV2Tapped() {
    guard let tracker = ATTNEventTracker.sharedInstance() else {
      print("Error: ATTNEventTracker not initialized")
      showToast(with: "Error: ATTNEventTracker not initialized")
      return
    }

    let productV2 = ATTNProduct(
      productId: product.productId,
      variantId: product.productVariantId,
      name: product.name ?? "Unknown Product",
      variantName: nil,
      imageUrl: product.productImage,
      categories: product.category != nil ? [product.category!] : nil,
      price: product.price.price.stringValue,
      quantity: product.quantity,
      productUrl: nil
    )

    tracker.recordAddToCart(product: productV2, currency: product.price.currency)

    delegate?.productDetailViewController(self, didAddToCart: product)

    showToast(with: "V2 AddToCart event sent!")
  }

  private func recordNewProductViewEvent() {
      guard let tracker = ATTNEventTracker.sharedInstance() else {
        print("Error: ATTNEventTracker not initialized")
        return
      }

      // Create a product
      let product = ATTNProduct(
          productId: "12345",
          variantId: "12345-A",
          name: "Wireless Controller",
          variantName: "Midnight Edition",
          imageUrl: "https://cdn.store.com/controller.jpg",
          categories: ["Electronics", "Gaming"],
          price: "59.99",
          quantity: 1,
          productUrl: "https://store.com/p/12345"
      )

      // Send the ProductView event via EventTracker
      tracker.recordProductView(product: product, currency: "USD")

      showToast(with: "New Product View event sent")
  }


}
