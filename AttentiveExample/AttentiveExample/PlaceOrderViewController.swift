//
//  PlaceOrderViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/6/25.
//

import UIKit

class PlaceOrderViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let cardNumberTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Card Number"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let cardHolderNameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Name on Card"
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let expirationDateTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Expiration Date (MM/YY)"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numbersAndPunctuation
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let cvvTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "CVV"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let placeOrderButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Place Order", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Place Order"
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        let stackView = UIStackView(arrangedSubviews: [
            cardNumberTextField,
            cardHolderNameTextField,
            expirationDateTextField,
            cvvTextField,
            placeOrderButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        placeOrderButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        placeOrderButton.addTarget(self, action: #selector(placeOrderTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func placeOrderTapped() {
        let cardNumber = cardNumberTextField.text ?? ""
        let cardHolderName = cardHolderNameTextField.text ?? ""
        let expirationDate = expirationDateTextField.text ?? ""
        let cvv = cvvTextField.text ?? ""

        // TODO: Validate fields & send purchase event
    }
}
