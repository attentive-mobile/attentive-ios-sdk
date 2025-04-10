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
  // Minimized creative's frame (when creative is minimized to a bubble instead of full screen)
  private(set) var minimizedFrame: CGRect?
  func updateMinimizedFrame(_ frame: CGRect) {
    minimizedFrame = frame
  }

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
    return CustomWebView(frame: .zero, configuration: configuration)
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

      Loggers.creative.debug("Setting up WebView for creative")

      DispatchQueue.main.async {
        let request = URLRequest(url: url)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: Constants.scriptMessageHandlerName)

        let userScriptWithEventListener = String(format: "window.addEventListener('message', (event) => {if (event.data && event.data.__attentive) {window.webkit.messageHandlers.log.postMessage(event.data.__attentive.action);}}, false);window.addEventListener('visibilitychange', (event) => {window.webkit.messageHandlers.log.postMessage(`%@ ${document.hidden}`);}, false);", Constants.visibilityEvent)
        let userScript = WKUserScript(source: userScriptWithEventListener, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)

        webViewProvider.webView = self.makeWebView()

        guard let webView = webViewProvider.webView as? CustomWebView else { return }

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
    if messageBody == "RESIZE_FRAME" {
      Loggers.creative.debug("Resizing creative")
      DispatchQueue.main.async {
        if let customWebView = self.webViewProvider?.webView as? CustomWebView {
          let getSizeJS =
            """
            (function() {
              var creative = document.getElementById('attentive_creative');
              if (creative) {
                var rect = creative.getBoundingClientRect();
                return JSON.stringify({ x: rect.x, y: rect.y, width: rect.width, height: rect.height });
              } else {
                return JSON.stringify({ x: 0, y: 0, width: document.body.scrollWidth, height: document.body.scrollHeight });
              }
            })();
            """
          customWebView.evaluateJavaScript(getSizeJS) { result, error in
            guard error == nil,
                  let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let rectDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: CGFloat],
                  let x = rectDict["x"],
                  let y = rectDict["y"],
                  let width = rectDict["width"],
                  let height = rectDict["height"] else {
              Loggers.creative.error("Failed to determine creative size: \(error?.localizedDescription ?? "unknown error")")
              return
            }

            var newArea: CGRect
            guard let parent = self.webViewProvider?.parentView else { return }
            let parentWidth = parent.bounds.width
            let parentHeight = parent.bounds.height
            //Check height to see if creative is a bubble, if so, scale creative frame to fit current screen coordinate system
            if height < 100 {
              // Converts the JavaScript-reported creative frame (in web coordinate space) into a native iOS hit area for CustomWebView, applying fixed calibration values for consistent behavior across different screen sizes.
              // This calibrated transformation yields an interactive area that's identical to creative's frame on screen. Then, if user taps inside the interactive area, the touch is handled by the creative; if user taps outside the interactive area, the touch is handled by rest of the app. This allows user to interact with the rest of the app while creative bubble remains on screen.

              // Use fixed horizontal calibration (works well on both large and small screens)
              let deltaX: CGFloat = 7.33
              // For vertical calibration, use a smaller offset on a smaller parent
              let deltaY: CGFloat = parentHeight < 800 ? 70 : 108.33
              // For width and height reductions, we keep the same values
              let reductionW: CGFloat = 14.83
              let reductionH: CGFloat = 15.0

              // Margins to slightly expand the hit area
              let marginX: CGFloat = 2.0
              let marginY: CGFloat = 2.0

              // Compute the converted values for iOS screen sizes:
              let screenX = x + deltaX - marginX
              let screenY = y + deltaY - marginY
              let screenWidth = width - reductionW + (marginX * 2)
              let screenHeight = height - reductionH + (marginY * 2)

//              // Determine a vertical shift using the window's safe area inset.
//              let verticalShift: CGFloat = {
//                  if let window = parent.window {
//                      return window.safeAreaInsets.top
//                  }
//                  return 0
//              }()
//
//              let adjustedY = screenY - verticalShift * 2
              //If screen is modal, apply the offset below (need to test with iphone SE)
              //otherwise, do default.
              let newFrame = CGRect(x: screenX,
                                      y: screenY - screenHeight * 2,
                                      width: screenWidth,
                                      height: screenHeight * 4)

              //
              //let newFrame = CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight)
              newArea = newFrame
            } else {
              newArea = parent.frame
            }

            customWebView.updateInteractiveHitArea(newArea)
            Loggers.creative.debug("Creative interactive area updated to: x: \(newArea.minX), y: \(newArea.minY), width: \(newArea.width), height: \(newArea.height)")
          }
        }
      }
    }
    if messageBody == "CLOSE" {
      closeCreative()
    } else if messageBody == "IMPRESSION" {
      stateManager.updateState(.open)
      Loggers.creative.debug("Creative opened and generated impression event")
    } else if messageBody == String(format: "%@ true", Constants.visibilityEvent), stateManager.getState() == .open {
      Loggers.creative.debug("WebView hidden, closing WebView")
      closeCreative()
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
/// Web view with custom hit area where only touches inside the interactive area are handled. This allows users to interact with rest of the app when creative is minimized to a bubble
class CustomWebView: WKWebView {

  var interactiveHitArea: CGRect = .zero {
    didSet {
      self.setNeedsLayout()
      self.layoutIfNeeded()
    }
  }

  func updateInteractiveHitArea(_ newArea: CGRect) {
    interactiveHitArea = newArea
  }


  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    return interactiveHitArea.contains(point)
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if interactiveHitArea.contains(point) {
      Loggers.creative.debug("inside area! point x is \(point.x) and y is \(point.y) TODO DELETE")
      return super.hitTest(point, with: event)
    }
    Loggers.creative.debug("outside area. point x is \(point.x) and y is \(point.y) TODO DELETE")
    return nil
  }
}

extension UIViewController {
  /// Returns true if the view controller is presented modally.
  var isModal: Bool {
    // If there's a presenting view controller, then we're modal…
    if self.presentingViewController != nil {
      return true
    }
    // Or if we're embedded in a navigation controller that itself was presented modally:
    if let nav = self.navigationController, nav.presentingViewController?.presentedViewController == nav {
      return true
    }
    // Or if we're embedded in a tab bar controller that was presented modally:
    if let tab = self.tabBarController, tab.presentingViewController is UITabBarController {
      return true
    }
    return false
  }

  var parentViewController: UIViewController? {
          var responder: UIResponder? = self
          while responder != nil {
              responder = responder?.next
              if let viewController = responder as? UIViewController {
                  return viewController
              }
          }
          return nil
      }
}

