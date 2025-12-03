//
//  ATTNCustomEvent+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

extension ATTNCustomEvent: ATTNEventRequestProvider {
    var eventRequests: [ATTNEventRequest] {
        var eventRequests = [ATTNEventRequest]()
        var customEventMetadata = [String: Any]()
        customEventMetadata["type"] = type
        customEventMetadata["properties"] =  try? ATTNJsonUtils.convertObjectToJson(properties) ?? "{}"

        eventRequests.append(ATTNEventRequest(metadata: customEventMetadata, eventNameAbbreviation: ATTNEventTypes.customEvent))
        return eventRequests
    }
}
