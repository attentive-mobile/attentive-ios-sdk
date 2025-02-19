//
//  ATTNWebViewHandling.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-07-04.
//

import Foundation
@preconcurrency import WebKit

protocol ATTNWebViewHandling {
  func launchCreative(parentView view: UIView, creativeId: String?, handler: ATTNCreativeTriggerCompletionHandler?)
  func closeCreative()
}

class ATTNWebViewHandler: NSObject, ATTNWebViewHandling {
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

  private weak var webViewProvider: ATTNWebViewProviding?
  private var urlBuilder: ATTNCreativeUrlProviding
  // a serial dispatch queue to synchronize access to webview to prevent race condition
  private let creativeQueue = DispatchQueue(label: "com.attentive.creativeQueue")
  private let stateManager: ATTNCreativeStateManager

  init(webViewProvider: ATTNWebViewProviding,
       creativeUrlBuilder: ATTNCreativeUrlProviding = ATTNCreativeUrlProvider(),
       stateManager: ATTNCreativeStateManager = .shared) {
    self.webViewProvider = webViewProvider
    self.urlBuilder = creativeUrlBuilder
    self.stateManager = stateManager
  }

  func makeWebView() -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.add(self, name: Constants.scriptMessageHandlerName)

    let userScriptWithEventListener = #"window.addEventListener('message', function(event) { if (event.data && event.data.__attentive) { window.webkit.messageHandlers.log.postMessage(event.data.__attentive.action); } }, false); window.addEventListener('visibilitychange', function(event) { window.webkit.messageHandlers.log.postMessage("\#(Constants.visibilityEvent) " + document.hidden); }, false);"#
    let userScript = WKUserScript(source: userScriptWithEventListener, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    configuration.userContentController.addUserScript(userScript)

    return WKWebView(frame: .zero, configuration: configuration)
  }

  func launchCreative(
    parentView view: UIView,
    creativeId: String? = nil,
    handler: ATTNCreativeTriggerCompletionHandler? = nil
  ) {
    creativeQueue.async { [self] in
      guard let webViewProvider = webViewProvider else {
        Loggers.creative.debug("Not showing the Attentive creative because the iOS version is too old.")
        webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
        return
      }

      webViewProvider.parentView = view
      webViewProvider.triggerHandler = handler

      Loggers.creative.debug("Called showWebView in creativeSDK with domain: \(self.domain, privacy: .public)")

      if stateManager.getState() != .closed {
        Loggers.creative.debug("Attempted to trigger creative, but creative is already launching or open. Taking no action.")
        return
      }
      stateManager.updateState(.launching)
      // Time out logic in case creative doesn't launch
      let timeoutInterval: TimeInterval = 5.0
      creativeQueue.asyncAfter(deadline: .now() + timeoutInterval) { [weak self] in
        guard let self = self, let webViewProvider = self.webViewProvider else { return }
        if self.stateManager.getState() == .launching {
          Loggers.creative.error("Creative launch timed out.")
          self.stateManager.updateState(.closed)
          DispatchQueue.main.async {
            webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
          }
        }
      }


      Loggers.creative.debug("The iOS version is new enough, continuing to show the Attentive creative.")

      let creativePageUrl = urlBuilder.buildCompanyCreativeUrl(
        configuration: ATTNCreativeUrlConfig(
          domain: domain,
          creativeId: creativeId,
          skipFatigue: webViewProvider.skipFatigueOnCreative,
          mode: mode.rawValue,
          userIdentity: userIdentity
        )
      )

      Loggers.creative.debug("Requesting creative page url: \(creativePageUrl)" )

      guard let url = URL(string: creativePageUrl) else {
        Loggers.creative.debug("URL could not be created.")
        stateManager.updateState(.closed)
        return
      }

      //stateManager.updateState(.open)// TODO: Move this to impression event when creative actually shows up
      Loggers.creative.debug("Setting up WebView for creative")

      DispatchQueue.main.async {
        let request = URLRequest(url: url)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: Constants.scriptMessageHandlerName)

        let userScriptWithEventListener = String(format: "window.addEventListener('message', (event) => {if (event.data && event.data.__attentive) {window.webkit.messageHandlers.log.postMessage(event.data.__attentive.action);}}, false);window.addEventListener('visibilitychange', (event) => {window.webkit.messageHandlers.log.postMessage(`%@ ${document.hidden}`);}, false);", Constants.visibilityEvent)
        let userScript = WKUserScript(source: userScriptWithEventListener, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)

        webViewProvider.webView = self.makeWebView()

        guard let webView = webViewProvider.webView else { return }

        webView.navigationDelegate = self
        webView.load(request)

        guard let parent = webViewProvider.parentView else { return }
        parent.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          webView.topAnchor.constraint(equalTo: parent.topAnchor),
          webView.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
          webView.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
          webView.trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])

        if self.mode == .debug {
          webViewProvider.parentView?.addSubview(webView)
        } else {
          webView.isOpaque = false
          webView.backgroundColor = .clear
        }
      }
    }
  }

  func closeCreative() {
    DispatchQueue.main.async {
      if let webView = self.webViewProvider?.webView {
        webView.navigationDelegate = nil
        webView.removeFromSuperview()
        webView.stopLoading()
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.scriptMessageHandlerName)
      }
      self.webViewProvider?.webView = nil
    }

    creativeQueue.async { [self] in
      stateManager.updateState(.closed)
      self.webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.closed)
      Loggers.creative.debug("Successfully closed creative")
    }
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
      guard let self = self, let webViewProvider = self.webViewProvider else { return }
      guard case let .success(statusAny) = result else {
        Loggers.creative.debug("No status returned from JS. Not showing WebView.")
        webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
        return
      }

      switch ScriptStatus.getRawValue(from: statusAny) {
      case .success:
        Loggers.creative.debug("Found creative iframe, showing WebView.")
        if self.mode == .production {
          webViewProvider.parentView?.addSubview(webView)
        }
        webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.opened)
      case .timeout:
        Loggers.creative.error("Creative timed out. Not showing WebView.")
        webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
      case .unknown(let statusString):
        Loggers.creative.error("Received unknown status: \(statusString). Not showing WebView")
        webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
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
    let messageBody = message.body as? String ?? "'Empty'"
    Loggers.creative.debug("Web event message: \(messageBody). is creative open: \(self.stateManager.getState() == .open ? "YES" : "NO")")

    if messageBody == "CLOSE" {
      closeCreative()
    } else if messageBody == "IMPRESSION" {
      stateManager.updateState(.open)
      Loggers.creative.debug("Creative opened and generated impression event")
    } else if messageBody == String(format: "%@ true", Constants.visibilityEvent), stateManager.getState() == .open {
      Loggers.creative.debug("WebView hidden, ignoring since we want user to close manually")
      // Do NOT call closeCreative() here otherwise web view will close prematurely. In many iOS WebKit edge cases especially while the page is still loading, document.hidden can be set to true momentarily, or iOS can inject a “visibilitychange” event at times you do not expect (such as while the view is transitioning)
    }
  }
}

fileprivate extension ATTNWebViewHandler {
  var domain: String {
    webViewProvider?.getDomain() ?? ""
  }
  var mode: ATTNSDKMode {
    webViewProvider?.getMode() ?? .production
  }
  var userIdentity: ATTNUserIdentity {
    webViewProvider?.getUserIdentity() ?? .init()
  }
  var skipFatigueOnCreative: Bool {
    webViewProvider?.skipFatigueOnCreative ?? false
  }
}
