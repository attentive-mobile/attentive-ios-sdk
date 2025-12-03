//
//  ATTNOrder.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNOrder)
public final class ATTNOrder: NSObject {
    @objc public var orderId: String

    @objc(initWithOrderId:)
    public init(orderId: String) {
        self.orderId = orderId
    }

    private override init() {
        fatalError("init() has not been implemented")
    }
}
