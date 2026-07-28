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

    /// Authoritative cart total when the host wants to override the SDK-computed
    /// value. When nil on a Purchase event, the SDK falls back to summing item
    /// prices (matching the legacy `/e` path).
    @objc public var cartTotal: String?

    /// Discount applied to the cart. Passed through unchanged on the v2 payload.
    @objc public var cartDiscount: String?

    @objc
    override public init() { }

    @objc
    public init(cartId: String? = nil, cartCoupon: String? = nil) {
        self.cartId = cartId
        self.cartCoupon = cartCoupon
    }
}
