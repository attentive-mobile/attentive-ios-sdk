//
//  LoginViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/7/25.
//

import UIKit

class LoginViewController: UIViewController {

  // MARK: - UI Components

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.text = "Attentive Mobile Sample App"
    label.textAlignment = .center
    label.font = UIFont.boldSystemFont(ofSize: 24)
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let createAccountButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Create account", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
    button.backgroundColor = UIColor.systemBlue
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 8
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let continueAsGuestButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Continue as guest", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
    button.backgroundColor = UIColor.systemGreen
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 8
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let bottomStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    setupUI()
  }

  // MARK: - UI Setup

  private func setupUI() {
    view.addSubview(titleLabel)
    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
      titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
    ])

    bottomStackView.addArrangedSubview(createAccountButton)
    bottomStackView.addArrangedSubview(continueAsGuestButton)

    view.addSubview(bottomStackView)
    NSLayoutConstraint.activate([
      bottomStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      bottomStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      bottomStackView.topAnchor.constraint(equalTo: view.centerYAnchor)
    ])

    createAccountButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    continueAsGuestButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

    createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
    continueAsGuestButton.addTarget(self, action: #selector(continueAsGuestTapped), for: .touchUpInside)
  }

  // MARK: - Actions

  @objc private func createAccountTapped() {
    let createAccountVC = CreateAccountViewController()
    present(createAccountVC, animated: true)
  }

  @objc private func continueAsGuestTapped() {
    let productVC = ProductViewController()
    let navController = UINavigationController(rootViewController: productVC)
    navController.modalPresentationStyle = .fullScreen
    present(navController, animated: true, completion: nil)
  }
}
