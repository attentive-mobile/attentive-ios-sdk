//
//  ATTNWebViewHandling.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-07-04.
//

import Foundation
import WebKit

protocol ATTNWebViewHandling {
  func launchCreative(parentView view: UIView, creativeId: String?, handler: ATTNCreativeTriggerCompletionHandler?)
  func closeCreative()
}

final class ATTNWebViewHandler: NSObject, ATTNWebViewHandling {
  private enum Constants {
    static var visibilityEvent: String { "document-visibility:" }
    static var scriptMessageHandlerName: String { "log" }
  }

  private enum ScriptStatus {
    case success
    case timeout
    case unknown(String)

    static func getRawValue(from value: Any) -> ScriptStatus? {
      guard let stringValue = value as? String else { return nil }
      switch stringValue {
      case "SUCCESS":
        return .success
      case "TIMED OUT":
        return .timeout
      default:
        return .unknown(stringValue)
      }
    }
  }

  private weak var sdk: ATTNSDK?
  private var urlBuilder: ATTNCreativeUrlProviding

  init(sdk: ATTNSDK, creativeUrlBuilder: ATTNCreativeUrlProviding) {
    self.sdk = sdk
    self.urlBuilder = creativeUrlBuilder
  }

  func launchCreative(
    parentView view: UIView,
    creativeId: String? = nil,
    handler: ATTNCreativeTriggerCompletionHandler? = nil
  ) {
    guard let sdk = sdk else {
      Loggers.creative.debug("Not showing the Attentive creative because the iOS version is too old.")
      sdk?.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
      return
    }

    sdk.parentView = view
    sdk.triggerHandler = handler

    let domain = sdk.getDomain()
    let mode = sdk.getMode()
    let userIdentity = sdk.userIdentity

    Loggers.creative.debug("Called showWebView in creativeSDK with domain: \(domain, privacy: .public)")

    guard !ATTNSDK.isCreativeOpen else {
      Loggers.creative.debug("Attempted to trigger creative, but creative is currently open. Taking no action")
      return
    }

    Loggers.creative.debug("The iOS version is new enough, continuing to show the Attentive creative.")

    let creativePageUrl = urlBuilder.buildCompanyCreativeUrl(
      configuration: ATTNCreativeUrlConfig(
        domain: domain,
        creativeId: creativeId,
        skipFatigue: sdk.skipFatigueOnCreative,
        mode: mode.rawValue,
        userIdentity: userIdentity
      )
    )

    Loggers.creative.debug("Requesting creative page url: \(creativePageUrl)" )

    guard let url = URL(string: creativePageUrl) else {
      Loggers.creative.debug("URL could not be created.")
      return
    }

    let request = URLRequest(url: url)

    let configuration = WKWebViewConfiguration()
    configuration.userContentController.add(self, name: Constants.scriptMessageHandlerName)

    let userScriptWithEventListener = String(format: "window.addEventListener('message', (event) => {if (event.data && event.data.__attentive) {window.webkit.messageHandlers.log.postMessage(event.data.__attentive.action);}}, false);window.addEventListener('visibilitychange', (event) => {window.webkit.messageHandlers.log.postMessage(`%@ ${document.hidden}`);}, false);", Constants.visibilityEvent)
    let userScript = WKUserScript(source: userScriptWithEventListener, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    configuration.userContentController.addUserScript(userScript)

    sdk.webView = WKWebView(frame: view.frame, configuration: configuration)

    guard let webView = sdk.webView else { return }

    webView.navigationDelegate = self
    webView.load(request)

    if mode == .debug {
      sdk.parentView?.addSubview(webView)
    } else {
      webView.isOpaque = false
      webView.backgroundColor = .clear
    }
  }

  func closeCreative() {
    sdk?.removeWebView()
    ATTNSDK.isCreativeOpen = false
    sdk?.triggerHandler?(ATTNCreativeTriggerStatus.closed)
    Loggers.creative.debug("Successfully closed creative")
  }
}

extension ATTNWebViewHandler: WKNavigationDelegate {
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard #available(iOS 14.0, *) else { return }
    let asyncJs =
        """
        var p = new Promise(resolve => {
            var timeoutHandle = null;
            const interval = setInterval(function() {
                e = document.querySelector('iframe');
                if(e && e.id === 'attentive_creative') {
                    clearInterval(interval);
                    resolve('SUCCESS');
                    if (timeoutHandle != null) {
                        clearTimeout(timeoutHandle);
                    }
                }
            }, 100);
            timeoutHandle = setTimeout(function() {
                clearInterval(interval);
                resolve('TIMED OUT');
            }, 5000);
        });
        var status = await p;
        return status;
        """
    webView.callAsyncJavaScript(
      asyncJs,
      in: nil,
      in: .defaultClient
    ) { [weak self] result in
      guard let self = self, let sdk = self.sdk else { return }
      guard case let .success(statusAny) = result else {
        Loggers.creative.debug("No status returned from JS. Not showing WebView.")
        self.sdk?.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
        return
      }

      switch ScriptStatus.getRawValue(from: statusAny) {
      case .success:
        Loggers.creative.debug("Found creative iframe, showing WebView.")
        if sdk.getMode() == .production {
          sdk.parentView?.addSubview(webView)
        }
        sdk.triggerHandler?(ATTNCreativeTriggerStatus.opened)
      case .timeout:
        Loggers.creative.error("Creative timed out. Not showing WebView.")
        sdk.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
      case .unknown(let statusString):
        Loggers.creative.error("Received unknown status: \(statusString). Not showing WebView")
        sdk.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
      default: break
      }
    }
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let url = navigationAction.request.url else {
      decisionHandler(.cancel)
      return
    }

    if url.scheme == "sms" {
      UIApplication.shared.open(url)
      decisionHandler(.cancel)
    } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
      if navigationAction.targetFrame == nil {
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
      } else {
        decisionHandler(.allow)
      }
    } else {
      decisionHandler(.allow)
    }
  }
}

extension ATTNWebViewHandler: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    let messageBody = message.body as? String ?? ""
    Loggers.creative.debug("Web event message: \(messageBody). isCreativeOpen: \(ATTNSDK.isCreativeOpen ? "YES" : "NO")")

    if messageBody == "CLOSE" {
      closeCreative()
    } else if messageBody == "IMPRESSION" {
      Loggers.creative.debug("Creative opened and generated impression event")
      ATTNSDK.isCreativeOpen = true
    } else if messageBody == String(format: "%@ true", Constants.visibilityEvent), ATTNSDK.isCreativeOpen {
      Loggers.creative.debug("Nav away from creative, closing")
      closeCreative()
    }
  }
}
