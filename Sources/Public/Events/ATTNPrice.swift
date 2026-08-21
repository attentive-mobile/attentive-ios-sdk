//
//  ATTNPrice.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNPrice)
public final class ATTNPrice: NSObject {
    @objc public let amount: NSDecimalNumber
    @objc public let currency: String

    @available(*, deprecated, renamed: "amount", message: "Use `amount`; `price` will be removed in the next major version.")
    @objc public var price: NSDecimalNumber { amount }

    @objc(initWithAmount:currency:)
    public init(amount: NSDecimalNumber, currency: String) {
        self.amount = amount
        self.currency = currency
        super.init()
    }

    @available(*, deprecated, renamed: "init(amount:currency:)", message: "Use `init(amount:currency:)`; this shim will be removed in the next major version.")
    @objc(initWithPrice:currency:)
    public convenience init(price: NSDecimalNumber, currency: String) {
        self.init(amount: price, currency: currency)
    }

    override private init() {
        fatalError("init() has not been implemented")
    }
}
