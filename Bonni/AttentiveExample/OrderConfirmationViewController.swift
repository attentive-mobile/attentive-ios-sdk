//
//  OrderConfirmationViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/7/25.
//

import UIKit

class OrderConfirmationViewController: UIViewController {

  // MARK: - UI Components

  private let thankYouLabel: UILabel = {
    let label = UILabel()
    label.text = "Thank you for shopping with us!"
    label.textAlignment = .center
    label.font = UIFont.boldSystemFont(ofSize: 24)
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    title = "Order Confirmed"
    setupUI()
    setupCloseButton()
  }

  // MARK: - UI Setup

  private func setupUI() {
    view.addSubview(thankYouLabel)
    NSLayoutConstraint.activate([
      thankYouLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      thankYouLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      thankYouLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      thankYouLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
    ])
  }

  private func setupCloseButton() {
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closeTapped))
  }

  // MARK: - Actions

  @objc private func closeTapped() {
    navigationController?.popToRootViewController(animated: true)
  }
}
