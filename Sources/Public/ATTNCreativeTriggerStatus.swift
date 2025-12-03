//
//  ATTNCreativeTriggerStatus.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

@objc public class ATTNCreativeTriggerStatus: NSObject {
    /// Status passed to `ATTNCreativeTriggerCompletionHandler` when the creative is opened successfully
    @objc public static let opened = "CREATIVE_TRIGGER_STATUS_OPENED"
    /// Status passed to `ATTNCreativeTriggerCompletionHandler` when the creative is closed sucessfully
    @objc public static let closed = "CREATIVE_TRIGGER_STATUS_CLOSED"
    /** Status passed to the`ATTNCreativeTriggerCompletionHandler` when the Creative has been triggered but it is not
     opened successfully. This can happen if there is no available mobile app creative, if the creative
     is fatigued, if the creative call has been timed out, or if an unknown exception occurs.
    */
    @objc public static let notOpened = "CREATIVE_TRIGGER_STATUS_NOT_OPENED"
    /// Status passed to the `ATTNCreativeTriggerCompletionHandler` when the Creative is not closed due to an unknown exception
    @objc public static let notClosed = "CREATIVE_TRIGGER_STATUS_NOT_CLOSED"
}
