//
//  LoginViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/7/25.
//

import UIKit

class LoginViewController: UIViewController {

  // MARK: - UI Components

  private let backgroundImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = UIImage(named: "LoginBackground")
    imageView.contentMode = .scaleAspectFill
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  private let greetingLabel: UILabel = {
    let label = UILabel()
    label.text = "HEY BESTIE!"
    label.font = UIFont(name: "Degular-Medium", size: 24)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let welcomeLabel: UILabel = {
    let label = UILabel()
    // "Bonny Beauty" will appear on a new line.
    label.text = "Welcome to\nBonny Beauty!"
    label.font = UIFont(name: "Degular-Medium", size: 28)
    label.textAlignment = .center
    label.numberOfLines = 0
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
    // Add background image view first so it sits behind all other views.
    view.addSubview(backgroundImageView)
    NSLayoutConstraint.activate([
      backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
      backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])

    // Add and layout the greeting and welcome labels.
    view.addSubview(greetingLabel)
    view.addSubview(welcomeLabel)
    NSLayoutConstraint.activate([
      // Position greetingLabel approximately one third from the top of the safe area.
      greetingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 200),
      greetingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      greetingLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

      // Place welcomeLabel directly below greetingLabel with a small gap.
      welcomeLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 8),
      welcomeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      welcomeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
    ])

    // Setup bottom stack view with buttons.
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
