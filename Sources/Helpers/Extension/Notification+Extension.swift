//
//  Notification+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Adela Gao on 6/5/25.
//

import Foundation

extension Notification.Name {
        /// Posted when the SDK extracts a valid deep-link URL from a tapped push.
        /// The `userInfo` contains `["attentivePushDeeplinkUrl": URL]`.
        public static let ATTNSDKDeepLinkReceived = Notification.Name("ATTNSDKDeepLinkReceived")

        /// Posted when the user taps an inbox message row in the built-in `InboxView`.
        /// Host apps can observe this to route to the message's `actionURL`.
        /// The `userInfo` contains:
        ///   - `"attentiveInboxMessageId"`: `Message.ID` (String) — always present
        ///   - `"attentiveInboxActionUrl"`: `URL` — present only when the message has a valid `actionURL`
        public static let ATTNSDKInboxMessageTapped = Notification.Name("ATTNSDKInboxMessageTapped")

        /// Posted whenever the inbox unread count changes. Provides a UIKit-friendly alternative
        /// to `ATTNSDK.inboxStateStream` for Swift hosts driving an unread badge without adopting
        /// Swift Concurrency.
        ///
        /// - `object`: the `ATTNSDK` instance that owns the count. Filter by this when running
        ///   multiple SDK instances; pass `nil` to observe all instances.
        /// - `userInfo["unreadCount"]`: `Int` — the new server-authoritative count.
        ///
        /// The notification is dispatched from whichever thread wrote the count. Observers that
        /// touch UIKit should register with `queue: .main` or hop to main before reading.
        /// Same-value writes are deduped, so a re-fetch that returns the same count does not fire.
        public static let ATTNSDKInboxUnreadCountChanged = Notification.Name("ATTNSDKInboxUnreadCountChanged")
}
