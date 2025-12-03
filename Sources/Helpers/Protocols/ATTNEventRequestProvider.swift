//
//  ATTNEventRequestProvider.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

protocol ATTNEventRequestProvider where Self: ATTNEvent {
    var eventRequests: [ATTNEventRequest] { get }
}
