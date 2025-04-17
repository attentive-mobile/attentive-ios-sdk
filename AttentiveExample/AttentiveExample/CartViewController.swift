//
//  CartViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/5/25.
//

import UIKit
import ATTNSDKFramework

class CartViewController: UIViewController {
  
  private let tableView = UITableView()
  private let viewModel: ProductListViewModel
  
  init(viewModel: ProductListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "My Cart"
    view.backgroundColor = .white
    
    setupTableView()
    setupCheckoutButton()
    
  }
  
  private func setupTableView() {
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.delegate = self
    tableView.dataSource = self
    tableView.register(CartTableViewCell.self, forCellReuseIdentifier: "CartCell")
    tableView.rowHeight = 130
    tableView.separatorStyle = .singleLine
    tableView.separatorColor = .black
    tableView.separatorInset = .init(top: 0, left: 8, bottom: 0, right: 0)
    
    view.addSubview(tableView)
    
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60) // Leaves space for checkout button
    ])
  }
  
  private func setupCheckoutButton() {
    let checkoutButton = UIButton(type: .system)
    checkoutButton.setTitle("Check Out", for: .normal)
    checkoutButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    checkoutButton.backgroundColor = .systemBlue
    checkoutButton.setTitleColor(.white, for: .normal)
    checkoutButton.layer.cornerRadius = 10
    checkoutButton.addTarget(self, action: #selector(checkoutTapped), for: .touchUpInside)
    
    checkoutButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(checkoutButton)
    
    NSLayoutConstraint.activate([
      checkoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      checkoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      checkoutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
      checkoutButton.heightAnchor.constraint(equalToConstant: 50)
    ])
  }
  @objc private func checkoutTapped() {
    let addressVC = AddressViewController()
    navigationController?.pushViewController(addressVC, animated: true)
  }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension CartViewController: UITableViewDataSource, UITableViewDelegate {
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return viewModel.cartItems.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "CartCell", for: indexPath) as? CartTableViewCell else {
      return UITableViewCell()
    }
    
    let cartItem = viewModel.cartItems[indexPath.row]
    cell.configure(with: cartItem.product, quantity: cartItem.quantity)
    cell.delegate = self
    return cell
  }
  
}

// MARK: - CartTableViewCellDelegate
extension CartViewController: CartTableViewCellDelegate {
  func didTapIncrease(in cell: CartTableViewCell) {
    guard let row = tableView.indexPath(for: cell)?.row else { return }
    let product = viewModel.cartItems[row].product
    viewModel.addProductToCart(product)
    tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
  }
  
  func didTapDecrease(in cell: CartTableViewCell) {
    guard let row = tableView.indexPath(for: cell)?.row else { return }
    let product = viewModel.cartItems[row].product
    viewModel.decreaseQuantity(of: product)
    
    // If still present, reload; otherwise delete the row
    if row < viewModel.cartItems.count {
      tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
    } else {
      tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .automatic)
    }
  }
}
