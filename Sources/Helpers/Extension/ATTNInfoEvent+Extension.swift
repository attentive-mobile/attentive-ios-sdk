//
//  ATTNInfoEvent+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

extension ATTNInfoEvent: ATTNEventRequestProvider {
    var eventRequests: [ATTNEventRequest] {
        [
            .init(metadata: [String: Any](), eventNameAbbreviation: ATTNEventTypes.info)
        ]
    }
}
