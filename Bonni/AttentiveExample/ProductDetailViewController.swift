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
          button.setTitle("Add to Cart", for: .normal)
          button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
          button.backgroundColor = .systemBlue
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
    recordProductViewEvent()
  }

  // MARK: - Setup UI

  private func setupUI() {
    view.addSubview(productImageView)
    view.addSubview(productNameLabel)
    view.addSubview(addToCartButton)
    addToCartButton.addTarget(self, action: #selector(addToCartTapped), for: .touchUpInside)

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

  private func recordNewProductViewEvent() {
    let product = ATTNProduct(
        productId: "12345",
        variantId: nil,
        name: "Wireless Controller",
        variantName: nil,
        imageUrl: "https://cdn.store.com/controller.jpg",
        categories: ["Electronics"],
        price: "59.99",
        quantity: 1,
        productUrl: "https://store.com/p/12345"
    )

    let metadata = ATTNProductViewMetadata(product: product, currency: "USD")

    let event = ATTNBaseEvent(
        visitorId: userIdentity.visitorId,
        version: "2.0.2",
        attentiveDomain: domain,
        locationHref: "https://store.com/p/12345",
        referrer: "https://store.com/home",
        eventType: .productView,
        timestamp: ISO8601DateFormatter().string(from: Date()),
        identifiers: userIdentity.toIdentifiers(),
        eventMetadata: metadata
    )

    // Example legacy eventRequest
    let eventRequest = ATTNEventRequest(eventNameAbbreviation: "d", metadata: [:])

    api.sendNewEvent(event: event, eventRequest: eventRequest, userIdentity: userIdentity)
  }
}
