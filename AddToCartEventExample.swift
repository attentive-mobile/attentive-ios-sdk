//
//  AddToCartEventExample.swift
//  Example of how to send an AddToCart event using the new v2 endpoint
//
//  This example shows how to create and send an AddToCart event that matches
//  the Android SDK payload format.
//

import Foundation
import ATTNSDKFramework

func sendAddToCartEventExample() {
    // 1️⃣ Get the EventTracker instance
    guard let tracker = ATTNEventTracker.sharedInstance() else {
        print("❌ ATTN SDK not initialized")
        return
    }

    // 2️⃣ Create the product
    let product = ATTNProduct(
        productId: "productId1",
        variantId: "variantId1",
        name: "The Stick",
        variantName: nil,
        imageUrl: nil,
        categories: nil,
        price: "20.00",
        quantity: 1,
        productUrl: nil
    )

    // 3️⃣ Send the AddToCart event via EventTracker
    tracker.recordAddToCart(product: product, currency: "USD")

    print("✅ AddToCart event sent via EventTracker")
}

// MARK: - Other Event Examples

func sendProductViewEventExample() {
    guard let tracker = ATTNEventTracker.sharedInstance() else {
        print("❌ ATTN SDK not initialized")
        return
    }

    let product = ATTNProduct(
        productId: "productId1",
        variantId: "variantId1",
        name: "Premium Widget",
        variantName: "Blue",
        imageUrl: "https://example.com/widget.jpg",
        categories: ["Electronics", "Gadgets"],
        price: "49.99",
        quantity: 1,
        productUrl: "https://example.com/products/widget"
    )

    tracker.recordProductView(product: product, currency: "USD")
}

func sendPurchaseEventExample() {
    guard let tracker = ATTNEventTracker.sharedInstance() else {
        print("❌ ATTN SDK not initialized")
        return
    }

    let product1 = ATTNProduct(
        productId: "productId1",
        variantId: "variantId1",
        name: "Product 1",
        variantName: nil,
        imageUrl: nil,
        categories: nil,
        price: "20.00",
        quantity: 2,
        productUrl: nil
    )

    let product2 = ATTNProduct(
        productId: "productId2",
        variantId: "variantId2",
        name: "Product 2",
        variantName: nil,
        imageUrl: nil,
        categories: nil,
        price: "30.00",
        quantity: 1,
        productUrl: nil
    )

    let cart = ATTNCartPayload(
        cartId: "cart123",
        cartTotal: "70.00",
        cartCoupon: "SAVE10",
        cartDiscount: "7.00"
    )

    tracker.recordPurchase(
        orderId: "order123",
        currency: "USD",
        orderTotal: "63.00",
        cart: cart,
        products: [product1, product2]
    )
}

// MARK: - Expected Payload Format
/*
 The iOS SDK will now send a payload that matches Android:

 POST https://events.attentivemobile.com/mobile
 Content-Type: application/x-www-form-urlencoded; charset=utf-8

 d=%7B%22visitorId%22%3A%22...%22%2C%22version%22%3A%22...%22%2C...%7D

 When decoded, the JSON looks like:
 {
   "visitorId": "d486315e97d44d6da3cfad1407b23247",
   "version": "2.0.5",
   "attentiveDomain": "games",
   "eventType": "AddToCart",  // ✅ Full string, not "c"
   "timestamp": "2025-11-03T20:40:08.981Z",
   "identifiers": {
     "encryptedEmail": "ZnNhZmZzQGFzYWRmZGwuY29t",
     "encryptedPhone": null,  // ✅ Explicit null
     "otherIdentifiers": null  // ✅ Explicit null
   },
   "eventMetadata": {
     "eventType": "AddToCart",
     "product": {
       "productId": "productId1",
       "variantId": "variantId1",
       "name": "The Stick",
       "variantName": null,
       "imageUrl": null,
       "categories": null,
       "price": "20.00",
       "quantity": 1,
       "productUrl": null
     },
     "currency": "USD"
   },
   "sourceType": "mobile",
   "referrer": "",
   "locationHref": null,  // ✅ Explicit null
   "genericMetadata": null,  // ✅ Explicit null
   "appSdk": "iOS"  // ✅ Set to "iOS" (Android uses "Android")
 }
 */
