//
//  ProductListViewModel.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/5/25.
//

import Foundation
import ATTNSDKFramework

class ProductListViewModel {

  // MARK: - Properties

  private(set) var products: [ATTNItem] = []
  private(set) var cartItems: [ATTNItem] = [] {
    didSet {
      onCartItemsChanged?(cartItems.count)
    }
  }

  var onCartItemsChanged: ((Int) -> Void)?

  // MARK: - Initialization

  init() {
    setupProducts()
  }

  private func setupProducts() {
    products = [
      ATTNItem(productId: "1", productVariantId: "1A", price: ATTNPrice(price: NSDecimalNumber(string: "19.99"), currency: "USD")),
      ATTNItem(productId: "2", productVariantId: "2A", price: ATTNPrice(price: NSDecimalNumber(string: "24.99"), currency: "USD")),
      ATTNItem(productId: "3", productVariantId: "3A", price: ATTNPrice(price: NSDecimalNumber(string: "14.99"), currency: "USD")),
      ATTNItem(productId: "4", productVariantId: "4A", price: ATTNPrice(price: NSDecimalNumber(string: "29.99"), currency: "USD")),
      ATTNItem(productId: "5", productVariantId: "5A", price: ATTNPrice(price: NSDecimalNumber(string: "9.99"), currency: "USD")),
      ATTNItem(productId: "6", productVariantId: "6A", price: ATTNPrice(price: NSDecimalNumber(string: "39.99"), currency: "USD"))
    ]
    assignMockDataToProducts()
  }

  private func assignMockDataToProducts() {
    let sampleImageNames = [
            "product1",
            "product2",
            "product3",
            "product4",
            "product5",
            "product6"
      ]
    let sampleProductNames = [
            "Protective Superscreen",
            "Mango Mask",
            "Coconut Balm",
            "Mango Balm",
            "Honeydew Balm",
            "The Stick"
    ]

    for (index, product) in products.enumerated() {
      product.name = sampleProductNames[index]
      product.productImage = sampleImageNames[index % sampleImageNames.count]
    }
  }

  // MARK: - Cart Operations

  func addProductToCart(_ product: ATTNItem) {
    cartItems.append(product)
  }

  func removeProductFromCart(at index: Int) {
    guard index < cartItems.count else { return }
    cartItems.remove(at: index)
  }
}
