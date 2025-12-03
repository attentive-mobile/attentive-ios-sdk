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
        label.attributedText = NSMutableAttributedString(string: "HEY BESTIE!", attributes: [NSAttributedString.Key.kern: 1.25])
        label.font = UIFont(name: "DegularDisplay-Medium", size: 28)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let welcomeLabel: UILabel = {
        let label = UILabel()
        // "Bonny Beauty" will appear on a new line.
        label.attributedText = NSMutableAttributedString(string: "Welcome to\nBonni Beauty!", attributes: [NSAttributedString.Key.kern: 1.25])
        label.font = UIFont(name: "DegularDisplay-Medium", size: 40)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let signInButton: UIButton = {
        let button = UIButton(type: .system)
        // Set background color from Figma design.
        button.backgroundColor = UIColor(red: 0.102, green: 0.118, blue: 0.133, alpha: 1)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Create a paragraph style for the button title.
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.04

        // Build attributed title for "SIGN IN"
        let attributes: [NSAttributedString.Key: Any] = [
            .kern: 1,
            .paragraphStyle: paragraphStyle,
            .font: UIFont(name: "Degular-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.white
        ]
        let attributedTitle = NSAttributedString(string: "SIGN IN", attributes: attributes)
        button.setAttributedTitle(attributedTitle, for: .normal)

        return button
    }()

    // Updated CONTINUE AS GUEST button
    private let continueAsGuestButton: UIButton = {
        let button = UIButton(type: .system)
        // White background with a 1pt black border.
        button.backgroundColor = UIColor.white
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.black.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false

        // Create paragraph style for the button title.
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.04

        let attributes: [NSAttributedString.Key: Any] = [
            .kern: 1,
            .paragraphStyle: paragraphStyle,
            .font: UIFont(name: "Degular-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.102, green: 0.118, blue: 0.133, alpha: 1)
        ]
        let attributedTitle = NSAttributedString(string: "CONTINUE AS GUEST", attributes: attributes)
        button.setAttributedTitle(attributedTitle, for: .normal)

        return button
    }()

    private let createAccountButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.04

        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .kern: 1,
            .paragraphStyle: paragraphStyle,
            .font: UIFont(name: "Degular-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.102, green: 0.118, blue: 0.133, alpha: 1)
        ]
        let attributedTitle = NSAttributedString(string: "Create Account", attributes: attributes)
        button.setAttributedTitle(attributedTitle, for: .normal)
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
        // Add the background image so it sits behind everything.
        view.addSubview(backgroundImageView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Add and position the greeting and welcome labels.
        view.addSubview(greetingLabel)
        view.addSubview(welcomeLabel)
        NSLayoutConstraint.activate([
            // Position greetingLabel about one third from the top.
            greetingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            greetingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Place welcomeLabel directly below greetingLabel.
            welcomeLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 8),
            welcomeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // Set up the bottom stack view with our two buttons.
        bottomStackView.addArrangedSubview(signInButton)
        bottomStackView.addArrangedSubview(continueAsGuestButton)
        bottomStackView.addArrangedSubview(createAccountButton)
        view.addSubview(bottomStackView)
        NSLayoutConstraint.activate([
            bottomStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            bottomStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            bottomStackView.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 80)
        ])

        signInButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
        continueAsGuestButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
        createAccountButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        continueAsGuestButton.addTarget(self, action: #selector(continueAsGuestTapped), for: .touchUpInside)
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func signInTapped() {
        // Handle sign in action. For example, present a sign-in screen.
        // TODO:
        showToast(with: "Hang tight—-Sign In is coming soon.")
    }

    @objc private func continueAsGuestTapped() {
        let productVC = ProductViewController()
        let navController = UINavigationController(rootViewController: productVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }

    @objc private func createAccountTapped() {
        // Handle sign in action. For example, present a sign-in screen.
        let createAccountVC = CreateAccountViewController()
        present(createAccountVC, animated: true)
    }
}
