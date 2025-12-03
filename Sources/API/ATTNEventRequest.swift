//
//  ATTNEventRequest.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-31.
//

import Foundation

// A single event can create multiple requests. The ATTNEventRequest class represents a single request.
@objc(ATTNEventRequest)
public final class ATTNEventRequest: NSObject {
    @objc public var metadata: [String: Any]
    @objc public let eventNameAbbreviation: String
    @objc public var deeplink: String?

    @objc(initWithMetadata:eventNameAbbreviation:)
    public init(metadata: [String: Any], eventNameAbbreviation: String) {
        self.metadata = metadata
        self.eventNameAbbreviation = eventNameAbbreviation
        super.init()
    }

    private override init() {
        fatalError("init() has not been implemented")
    }
}
