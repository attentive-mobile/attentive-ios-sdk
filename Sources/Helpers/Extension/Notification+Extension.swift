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
}
