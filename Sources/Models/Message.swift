//
//  Message.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/15/26.
//

import Foundation

public struct Message: Codable, Identifiable {
    public typealias ID = String
    
    public var id: ID
    public var title: String
    public var body: String
    public var timestamp: Date
    public var isRead: Bool
    public var imageURL: String?
    public var actionURL: String?
}
