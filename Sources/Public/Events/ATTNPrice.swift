//
//  ATTNPrice.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNPrice)
public final class ATTNPrice: NSObject {
    @objc public let price: NSDecimalNumber
    @objc public let currency: String

    @objc(initWithPrice:currency:)
    public init(price: NSDecimalNumber, currency: String) {
        self.price = price
        self.currency = currency
        super.init()
    }

    private override init() {
        fatalError("init() has not been implemented")
    }
}
