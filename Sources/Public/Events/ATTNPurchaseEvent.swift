//
//  ATTNPurchaseEvent.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNPurchaseEvent)
public class ATTNPurchaseEvent: NSObject, ATTNEvent {
    @objc public let items: [ATTNItem]
    @objc public let order: ATTNOrder
    @objc public var cart: ATTNCart?

    @objc(initWithItems:order:)
    public init(items: [ATTNItem], order: ATTNOrder) {
        self.items = items
        self.order = order
        super.init()
    }

    private override init() {
        fatalError("init() has not been implemented")
    }
}
