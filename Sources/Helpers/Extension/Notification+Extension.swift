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
}
