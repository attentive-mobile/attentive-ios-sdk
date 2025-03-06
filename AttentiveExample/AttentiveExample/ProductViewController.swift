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
  
  // MARK: - UI Components
  
  private let mainVStackView: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.alignment = .fill
    stack.distribution = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()
  
  private let settingsHStackView: UIStackView = {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.alignment = .fill
    stack.distribution = .fillEqually
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()
  
  private let settingsButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Settings", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  
  private let cartButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Cart", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  
  private let productsLabel: UILabel = {
    let label = UILabel()
    label.text = "Products"
    label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private let productsCollectionView: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.backgroundColor = .green
    return collectionView
  }()
  
  private let viewModel = ProductListViewModel()
  
  // MARK: - View Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    setupUI()
    setupCollectionView()
    setupButtonActions()
  }
  
  // MARK: - UI Setup
  
  private func setupUI() {
    view.addSubview(mainVStackView)
    
    // Add horizontal stack view with buttons
    settingsHStackView.addArrangedSubview(settingsButton)
    settingsHStackView.addArrangedSubview(cartButton)
    
    // Add views to main stack view
    mainVStackView.addArrangedSubview(settingsHStackView)
    mainVStackView.addArrangedSubview(productsLabel)
    mainVStackView.addArrangedSubview(productsCollectionView)
    
    // Constraints for main stack view
    NSLayoutConstraint.activate([
      mainVStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      mainVStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      mainVStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      mainVStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    
    // Set height constraint for horizontal stack view
    settingsHStackView.heightAnchor.constraint(equalToConstant: 50).isActive = true
    
    // Set height constraint for products label
    productsLabel.heightAnchor.constraint(equalToConstant: 30).isActive = true
    
    // CollectionView constraints (fills remaining space)
    NSLayoutConstraint.activate([
      productsCollectionView.leadingAnchor.constraint(equalTo: mainVStackView.leadingAnchor),
      productsCollectionView.trailingAnchor.constraint(equalTo: mainVStackView.trailingAnchor),
      productsCollectionView.bottomAnchor.constraint(equalTo: mainVStackView.bottomAnchor)
    ])
  }
  
  // MARK: - Collection View Setup
  
  private func setupCollectionView() {
    productsCollectionView.dataSource = self
    productsCollectionView.delegate = self
    productsCollectionView.register(ProductCollectionViewCell.self, forCellWithReuseIdentifier: "ProductCell")
  }
  
  private func setupButtonActions() {
    cartButton.addTarget(self, action: #selector(cartButtonTapped), for: .touchUpInside)
  }
  
  @objc private func cartButtonTapped() {
    let cartVC = CartViewController(viewModel: viewModel)
    navigationController?.pushViewController(cartVC, animated: true)
  }
  
  // MARK: - UICollectionView DataSource
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return viewModel.products.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath) as! ProductCollectionViewCell
    cell.backgroundColor = .lightGray // todo change
    let product = viewModel.products[indexPath.item]
    cell.configure(with: product)
    cell.delegate = self
    return cell
  }
  
  // MARK: - UICollectionView Delegate Flow Layout
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let width = (collectionView.frame.width - 30) / 2 // 2 columns with spacing
    return CGSize(width: width, height: width * 1.5)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return 10
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return 10
  }
}


class ProductViewController2: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  //  @IBAction func showCreativeButtonPressed(_ sender: Any) {
  //    self.clearCookies()
  //    do {
  //      let sdk = try self.getAttentiveSdk()
  //      sdk.trigger(self.view, creativeId: "1105292")
  //    } catch {
  //      os_log("Error triggering creative: %@", error.localizedDescription)
  //    }
  //  }
  
  
  
  private func clearCookies() {
    os_log("Clearing cookies!")
    
    WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeCookies], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {() -> Void in os_log("Cleared cookies!") })
  }
  
  private func getAttentiveSdk() throws -> ATTNSDK {
    guard let sdk = (UIApplication.shared.delegate as? AppDelegate)?.attentiveSdk else {
      throw AttentiveSDKError.sdkNotInitialized
    }
    return sdk
  }
}

// MARK: - ProductCollectionViewCellDelegate
extension ProductViewController: ProductCollectionViewCellDelegate {
  func didTapAddToCartButton(product: ATTNItem) {
    viewModel.addProductToCart(product)
  }
}
