//
//  ATTNProductViewEvent.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNProductViewEvent)
public final class ATTNProductViewEvent: NSObject, ATTNEvent {
    @objc public let items: [ATTNItem]
    @objc public var deeplink: String?

    @objc(initWithItems:)
    public convenience init(items: [ATTNItem]) {
        self.init(items: items, deeplink: nil)
    }

    @objc(initWithItems:deeplink:)
    public init(items: [ATTNItem], deeplink: String?) {
        self.items = items
        self.deeplink = deeplink
        super.init()
    }

    private override init() {
        fatalError("init() has not been implemented")
    }
}

extension ATTNProductViewEvent: ATTNDeeplinkHandling { }
