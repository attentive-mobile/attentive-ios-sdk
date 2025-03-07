//
//  AddressViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/6/25.
//

import UIKit

class AddressViewController: UIViewController {

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

  private let shippingTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "Shipping Address"
    label.font = UIFont.boldSystemFont(ofSize: 18)
    return label
  }()
  private let shippingFullNameTextField = AddressViewController.makeTextField(withPlaceholder: "Full Name")
  private let shippingStreetTextField = AddressViewController.makeTextField(withPlaceholder: "Street Address")
  private let shippingCityTextField = AddressViewController.makeTextField(withPlaceholder: "City")
  private let shippingStateTextField = AddressViewController.makeTextField(withPlaceholder: "State")
  private let shippingZipTextField = AddressViewController.makeTextField(withPlaceholder: "Zip Code")

  private let billingTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "Billing Address"
    label.font = UIFont.boldSystemFont(ofSize: 18)
    return label
  }()
  private let billingFullNameTextField = AddressViewController.makeTextField(withPlaceholder: "Full Name")
  private let billingStreetTextField = AddressViewController.makeTextField(withPlaceholder: "Street Address")
  private let billingCityTextField = AddressViewController.makeTextField(withPlaceholder: "City")
  private let billingStateTextField = AddressViewController.makeTextField(withPlaceholder: "State")
  private let billingZipTextField = AddressViewController.makeTextField(withPlaceholder: "Zip Code")

  private let continueButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Continue", for: .normal)
    button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    button.backgroundColor = .systemBlue
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 8
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    title = "Shipping & Billing"
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
      // Set contentView width equal to scrollView width
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
    ])

    let stackView = UIStackView(arrangedSubviews: [
      shippingTitleLabel,
      shippingFullNameTextField,
      shippingStreetTextField,
      shippingCityTextField,
      shippingStateTextField,
      shippingZipTextField,
      billingTitleLabel,
      billingFullNameTextField,
      billingStreetTextField,
      billingCityTextField,
      billingStateTextField,
      billingZipTextField,
      continueButton
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

    continueButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

    continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
  }

  private static func makeTextField(withPlaceholder placeholder: String) -> UITextField {
    let tf = UITextField()
    tf.placeholder = placeholder
    tf.borderStyle = .roundedRect
    tf.translatesAutoresizingMaskIntoConstraints = false
    return tf
  }

  // MARK: - Actions

  @objc private func continueTapped() {
    // TODO Validate the entered data
    let placeOrderVC = PlaceOrderViewController()
    navigationController?.pushViewController(placeOrderVC, animated: true)
  }
  


}
