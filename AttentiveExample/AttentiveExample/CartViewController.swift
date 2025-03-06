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
    // TODO
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

    let item = viewModel.cartItems[indexPath.row]
    cell.configure(with: item)
    cell.delegate = self
    cell.deleteAction = { [weak self] in
      self?.viewModel.removeProductFromCart(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .fade)
    }
    return cell
  }

  func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completionHandler in
      self?.viewModel.removeProductFromCart(at: indexPath.row)
      completionHandler(true)
    }
    deleteAction.backgroundColor = .systemRed
    return UISwipeActionsConfiguration(actions: [deleteAction])
  }
//
//  func removeItem(at index: Int) {
//    guard index < cartProducts.count else { return }
//
//    cartProducts.remove(at: index)
//
//    tableView.performBatchUpdates({
//      tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
//    }, completion: nil)
//  }
}

// MARK: - CartTableViewCellDelegate
extension CartViewController: CartTableViewCellDelegate {
  func didTapDeleteButton(in cell: CartTableViewCell) {
    guard let indexPath = tableView.indexPath(for: cell), indexPath.row < viewModel.cartItems.count  else { return }
    // trigger swipe to delete
    viewModel.removeProductFromCart(at: indexPath.row)
        tableView.performBatchUpdates({
          tableView.deleteRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .fade)
        }, completion: nil)
  }
}
