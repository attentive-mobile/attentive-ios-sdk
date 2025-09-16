//
//  PlaceOrderViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/6/25.
//

import UIKit
import ATTNSDKFramework
import os

/**
 This PlaceOrderViewController is currently unused.
 */
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
    // In PlaceOrderViewController, after a successful order:
    let orderConfirmationVC = OrderConfirmationViewController()
    navigationController?.pushViewController(orderConfirmationVC, animated: true)
    recordPlaceOrderEvent()
  }

  private func recordPlaceOrderEvent() {
    let item : ATTNItem = self.buildItem()
    // Create the Order
    let order : ATTNOrder = ATTNOrder(orderId: "778899")
    // Create PurchaseEvent
    let purchase : ATTNPurchaseEvent = ATTNPurchaseEvent(items: [item], order: order)
    // Send the PurchaseEvent
    ATTNEventTracker.sharedInstance()?.record(event: purchase)

    showToast(with: "Purchase Event sent")
  }

  func buildItem() -> ATTNItem {
    // Build Item with required fields
    let item : ATTNItem = ATTNItem(productId: "222", productVariantId: "55555", price: ATTNPrice(price: NSDecimalNumber(string: "15.99"), currency: "USD"))

    // Add some optional fields
    item.name = "T-Shirt"
    item.category = "Tops"

    return item
  }
}
