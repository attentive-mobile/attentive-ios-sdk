//
//  ProductViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/4/25.
//

import UIKit
import ATTNSDKFramework
import WebKit
import os.log

class ProductViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
  
  // MARK: - Constants
  
  private let kPadding: CGFloat = 24
  private let kStackSpacing: CGFloat = 16
  private let kNavColor = UIColor(red: 1, green: 0.773, blue: 0.725, alpha: 1)
  private let kLabelFontSize: CGFloat = 30
  private let kLabelKerning: CGFloat = 1.25
  
  // MARK: - UI Components
  
  private let mainVStackView: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.alignment = .fill
    stack.distribution = .fill
    stack.spacing = 16  // Will be updated in setupUI()
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()
  
  private lazy var allProductsLabel: UILabel = {
    let label = UILabel()
    label.textColor = UIColor(red: 0.102, green: 0.118, blue: 0.133, alpha: 1)
    label.font = UIFont(name: "Degular-Medium", size: kLabelFontSize)
    let attributedText = NSMutableAttributedString(string: "All Products", attributes: [
      .kern: kLabelKerning
    ])
    label.attributedText = attributedText
    label.textAlignment = .left
    // Ensure the label expands to fill available width.
    label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private let productsCollectionView: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    // Uncomment for debugging layout:
    // collectionView.backgroundColor = .green
    return collectionView
  }()
  
  private let viewModel = ProductListViewModel()
  
  // MARK: - View Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    setupNavigationBar()
    setupUI()
    setupCollectionView()
  }
  
  // MARK: - Navigation Bar Setup
  
  private func setupNavigationBar() {
    // Configure navigation bar appearance with desired background color.
    if #available(iOS 13.0, *) {
      let navBarAppearance = UINavigationBarAppearance()
      navBarAppearance.configureWithOpaqueBackground()
      navBarAppearance.backgroundColor = kNavColor
      navigationController?.navigationBar.standardAppearance = navBarAppearance
      navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
    } else {
      navigationController?.navigationBar.barTintColor = kNavColor
    }
    navigationController?.navigationBar.isTranslucent = false
    
    // Left bar button: settings using "profile" image.
    let settingsImage = UIImage(named: "profile")
    let settingsButtonItem = UIBarButtonItem(image: settingsImage, style: .plain, target: self, action: #selector(settingsButtonTapped))
    settingsButtonItem.tintColor = .black
    navigationItem.leftBarButtonItem = settingsButtonItem
    
    // Right bar button: cart using "Shopping cart" image.
    let cartImage = UIImage(named: "Shopping cart")
    let cartButtonItem = UIBarButtonItem(image: cartImage, style: .plain, target: self, action: #selector(cartButtonTapped))
    cartButtonItem.tintColor = .black
    navigationItem.rightBarButtonItem = cartButtonItem
    
    // Center the logo in the navigation bar.
    let logoImageView = UIImageView(image: UIImage(named: "Union.svg"))
    logoImageView.contentMode = .scaleAspectFit
    navigationItem.titleView = logoImageView
  }
  
  // MARK: - UI Setup
  
  private func setupUI() {
    view.addSubview(mainVStackView)
    mainVStackView.spacing = kStackSpacing
    
    // Add arranged subviews.
    mainVStackView.addArrangedSubview(allProductsLabel)
    mainVStackView.addArrangedSubview(productsCollectionView)
    
    // Constrain mainVStackView to the view with 24 points padding on all sides.
    NSLayoutConstraint.activate([
      mainVStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: kPadding),
      mainVStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: kPadding),
      mainVStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -kPadding),
      mainVStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -kPadding)
    ])
  }
  
  // MARK: - Collection View Setup
  
  private func setupCollectionView() {
    productsCollectionView.dataSource = self
    productsCollectionView.delegate = self
    productsCollectionView.register(ProductCollectionViewCell.self, forCellWithReuseIdentifier: "ProductCell")
  }
  
  // MARK: - Button Actions
  
  @objc private func cartButtonTapped() {
    let cartVC = CartViewController(viewModel: viewModel)
    navigationController?.pushViewController(cartVC, animated: true)
  }
  
  @objc private func settingsButtonTapped() {
    let settingsVC = SettingsViewController()
    navigationController?.pushViewController(settingsVC, animated: true)
  }
  
  @objc private func checkoutTapped() {
    let addressVC = AddressViewController()
    navigationController?.pushViewController(addressVC, animated: true)
  }
  
  // MARK: - UICollectionView DataSource
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return viewModel.products.count
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    guard let cell = collectionView
      .dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath)
            as? ProductCollectionViewCell else {
      fatalError("Could not dequeue ProductCollectionViewCell with identifier 'ProductCell'")
    }
    let product = viewModel.products[indexPath.item]
    cell.configure(with: product)
    cell.delegate = self
    return cell
  }

  // MARK: - UICollectionView Delegate Flow Layout
  
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      sizeForItemAt indexPath: IndexPath) -> CGSize {
      let numberOfColumns: CGFloat = 2
      let interItemSpacing: CGFloat = 10  // This should match your minimumInteritemSpacing
      let totalSpacing = interItemSpacing * (numberOfColumns - 1)

      let cellWidth = (collectionView.frame.width - totalSpacing) / numberOfColumns
      let aspectRatio: CGFloat = 245 / 165  // height = width * (245/165)
      let cellHeight = cellWidth * aspectRatio + 40

      return CGSize(width: cellWidth, height: cellHeight)
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return 10
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return 10
  }
}

// MARK: - ProductCollectionViewCellDelegate

extension ProductViewController: ProductCollectionViewCellDelegate {
  func didTapAddToCartButton(product: ATTNItem) {
    viewModel.addProductToCart(product)
    let addToCartEvent = ATTNAddToCartEvent(items: [product])
    ATTNEventTracker.sharedInstance()?.record(event: addToCartEvent)
    showToast(with: "Add To Cart event sent")
  }
  
  func didTapProductImage(product: ATTNItem) {
    let detailVC = ProductDetailViewController(product: product)
    detailVC.delegate = self
    navigationController?.pushViewController(detailVC, animated: true)
  }

  

}

extension ProductViewController: ProductDetailViewControllerDelegate {
  func productDetailViewController(_ controller: ProductDetailViewController, didAddToCart product: ATTNItem) {
    viewModel.addProductToCart(product)
    let addToCartEvent = ATTNAddToCartEvent(items: [product])
    ATTNEventTracker.sharedInstance()?.record(event: addToCartEvent)
    showToast(with: "Add To Cart event sent")
  }
}
