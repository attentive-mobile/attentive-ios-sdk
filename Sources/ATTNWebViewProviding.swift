//
//  ATTNWebViewProviding.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-07-04.
//

import WebKit

protocol ATTNWebViewProviding: NSObjectProtocol {
  var parentView: UIView? { get set }
  var webView: WKWebView? { get set }
  var skipFatigueOnCreative: Bool { get set }
  var triggerHandler: ATTNCreativeTriggerCompletionHandler? { get set }
  var isCreativeOpen: Bool { get set }

  func getDomain() -> String
  func getMode() -> ATTNSDKMode
  func getUserIdentity() -> ATTNUserIdentity
}
