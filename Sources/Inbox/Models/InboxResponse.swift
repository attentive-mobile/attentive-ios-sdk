//
//  InboxResponse.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 2/2/26.
//

struct InboxResponse: Codable {
    var messages: [Message]
    /// Opaque cursor returned by the server. Absent (or empty) when there are no more pages.
    var nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case messages
        case nextPageToken = "next_page_token"
    }
}
