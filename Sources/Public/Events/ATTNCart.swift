//
//  ATTNCart.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNCart)
public final class ATTNCart: NSObject {
    @objc public var cartId: String?
    @objc public var cartCoupon: String?

    @objc
    public override init() { }

    @objc
    public init(cartId: String? = nil, cartCoupon: String? = nil) {
        self.cartId = cartId
        self.cartCoupon = cartCoupon
    }
}
