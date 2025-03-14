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
    let sampleImages = [
      "https://via.placeholder.com/150/008000",
      "https://via.placeholder.com/150/008000",
      "https://via.placeholder.com/150/008000",
      "https://via.placeholder.com/150/FF0000",
      "https://via.placeholder.com/150/800080",
      "https://via.placeholder.com/150/FFA500"
    ]

    for (index, product) in products.enumerated() {
      product.name = "Product \(index + 1)"
      product.productImage = sampleImages[index % sampleImages.count]
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
