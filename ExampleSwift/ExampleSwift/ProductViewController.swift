//
//  ProductViewController.swift
//  ExampleSwift
//
//  Created by Wyatt Davis on 2/9/23.
//

import Foundation
import os

class ProductViewController : UIViewController {
    @IBOutlet var addToCartBtn : UIButton?
    @IBOutlet var purchaseBtn : UIButton?
    @IBOutlet weak var customEventBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let item : ATTNItem = buildItem()
        let productView : ATTNProductViewEvent = ATTNProductViewEvent(items: [item])
        ATTNEventTracker.sharedInstance().record(productView)
        
        showToast(message: "Product View event sent")
    }
    
    @IBAction func addToCartBtnPressed(sender: Any) {
        let item : ATTNItem = self.buildItem()
        let addToCart : ATTNAddToCartEvent = ATTNAddToCartEvent(items: [item])
        ATTNEventTracker.sharedInstance().record(addToCart)
        
        showToast(message: "Add To Cart event sent")
    }
    
    @IBAction func purchaseBtnPressed(sender: Any) {
        // Create the Items that were purchased
        let item : ATTNItem = self.buildItem()
        // Create the Order
        let order : ATTNOrder = ATTNOrder(orderId: "778899")
        // Create PurchaseEvent
        let purchase : ATTNPurchaseEvent = ATTNPurchaseEvent(items: [item], order: order)
        // Send the PurchaseEvent
        ATTNEventTracker.sharedInstance().record(purchase)
        
        showToast(message: "Purchase event sent")
    }
    
    @IBAction func customEventBtnPressed(sender: Any) {
        let customEvent : ATTNCustomEvent = ATTNCustomEvent(type: "Added to Wishlist", properties: ["wishlistName": "Gift Ideas"]);
        ATTNEventTracker.sharedInstance().record(customEvent)
        
        showToast(message: "Custom event sent")
    }

    func buildItem() -> ATTNItem {
        // Build Item with required fields
        let item : ATTNItem = ATTNItem(productId: "222", productVariantId: "55555", price: ATTNPrice(price: NSDecimalNumber(string: "15.99"), currency: "USD"))
        
        // Add some optional fields
        item.name = "T-Shirt"
        item.category = "Tops"
        
        return item
    }
    
    func showToast(message: String) {
        let alert : UIAlertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        self.present(alert, animated: true)
        
        let deadline = DispatchTime.now() + .seconds(1)
        
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            alert.dismiss(animated: true)
        }
    }
}
