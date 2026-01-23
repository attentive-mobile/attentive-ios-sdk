//
//  Message.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/15/26.
//

import Foundation

public struct Message: Codable, Identifiable, Sendable {
    // swiftlint:disable:next type_name
    public typealias ID = String

    public var id: ID
    public var title: String
    public var body: String
    public var timestamp: Date
    public var isRead: Bool
    public var imageURLString: String?
    public var actionURLString: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case timestamp
        case isRead = "is_read"
        case imageURLString = "image_url"
        case actionURLString = "action_url"
    }
    
    public var imageURL: URL? {
        imageURLString.flatMap(URL.init(string:))
    }
}
