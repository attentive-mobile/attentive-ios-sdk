//
//  Message.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/15/26.
//

import Foundation

public struct Message: Codable, Identifiable, Sendable {
    public enum Style: Codable, Sendable {
        case small
        case large
    }

    // swiftlint:disable:next type_name
    public typealias ID = String

    public var id: ID
    /// Client-side rendering hint. The server does not return this today; every message
    /// decoded from the API defaults to `.small`.
    public var style: Style
    public var title: String
    public var body: String
    /// When the message was sent by the server. Server field: `sent_at`.
    public var timestamp: Date
    public var isRead: Bool
    public var imageURLString: String?
    public var actionURLString: String?
    /// When the message expires and should no longer be shown. Absent means "never".
    public var expiresAt: Date?
    /// When the user last marked this message read. `nil` while unread.
    public var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "inbox_message_id"
        case style
        case title
        case body
        case timestamp = "sent_at"
        case isRead = "is_read"
        case imageURLString = "image_url"
        case actionURLString = "action_url"
        case expiresAt = "expires_at"
        case readAt = "read_at"
    }

    public init(
        id: ID,
        style: Style = .small,
        title: String,
        body: String,
        timestamp: Date,
        isRead: Bool,
        imageURLString: String? = nil,
        actionURLString: String? = nil,
        expiresAt: Date? = nil,
        readAt: Date? = nil
    ) {
        self.id = id
        self.style = style
        self.title = title
        self.body = body
        self.timestamp = timestamp
        self.isRead = isRead
        self.imageURLString = imageURLString
        self.actionURLString = actionURLString
        self.expiresAt = expiresAt
        self.readAt = readAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        // The server does not return `style` today; default to `.small` when absent so
        // synthesized encode-decode round-trips (e.g. host-app persistence) preserve the field.
        self.style = try container.decodeIfPresent(Style.self, forKey: .style) ?? .small
        self.title = try container.decode(String.self, forKey: .title)
        self.body = try container.decode(String.self, forKey: .body)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.isRead = try container.decode(Bool.self, forKey: .isRead)
        self.imageURLString = try container.decodeIfPresent(String.self, forKey: .imageURLString)
        self.actionURLString = try container.decodeIfPresent(String.self, forKey: .actionURLString)
        self.expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        self.readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
    }

    public var imageURL: URL? {
        imageURLString.flatMap(URL.init(string:))
    }

    public var actionURL: URL? {
        actionURLString.flatMap(URL.init(string:))
    }
}
