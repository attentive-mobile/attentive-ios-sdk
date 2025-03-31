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

  private weak var webViewProvider: ATTNWebViewProviding?
  private var urlBuilder: ATTNCreativeUrlProviding
  private var creativeWidthConstraint: NSLayoutConstraint?
  private var creativeHeightConstraint: NSLayoutConstraint?

  init(webViewProvider: ATTNWebViewProviding, creativeUrlBuilder: ATTNCreativeUrlProviding = ATTNCreativeUrlProvider()) {
    self.webViewProvider = webViewProvider
    self.urlBuilder = creativeUrlBuilder
  }

  func launchCreative(
    parentView view: UIView,
    creativeId: String? = nil,
    handler: ATTNCreativeTriggerCompletionHandler? = nil
  ) {
    guard let webViewProvider = webViewProvider else {
      Loggers.creative.debug("Not showing the Attentive creative because the iOS version is too old.")
      webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
      return
    }

    webViewProvider.parentView = view
    webViewProvider.triggerHandler = handler

    Loggers.creative.debug("Called showWebView in creativeSDK with domain: \(self.domain, privacy: .public)")

    guard !isCreativeOpen else {
      Loggers.creative.debug("Attempted to trigger creative, but creative is currently open. Taking no action")
      return
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
      return
    }

    DispatchQueue.main.async {
      let request = URLRequest(url: url)
      let configuration = WKWebViewConfiguration()
      configuration.userContentController.add(self, name: Constants.scriptMessageHandlerName)

      let userScriptWithEventListener = String(format: "window.addEventListener('message', (event) => { if (event.data && event.data.__attentive) { window.webkit.messageHandlers.log.postMessage(event.data.__attentive.action); } }, false); window.addEventListener('visibilitychange', (event) => { window.webkit.messageHandlers.log.postMessage(`%@ ${document.hidden}`); }, false);", Constants.visibilityEvent)
      let userScript = WKUserScript(source: userScriptWithEventListener, injectionTime: .atDocumentStart, forMainFrameOnly: false)
      configuration.userContentController.addUserScript(userScript)

      // Create a web view with the parent's frame.
      webViewProvider.webView = WKWebView(frame: view.frame, configuration: configuration)
      guard let webView = webViewProvider.webView else { return }
      webView.navigationDelegate = self
      webView.load(request)

      // For production, add the web view to the container view if provided.
      if self.mode == .production {
        if let container = webViewProvider.containerView {
          container.addSubview(webView)
          // Setup auto-layout constraints if needed.
          webView.translatesAutoresizingMaskIntoConstraints = false
          NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
          ])
        } else if let parent = webViewProvider.parentView {
          // Fallback if no container view is provided.
          parent.addSubview(webView)
        }
      }
      else if self.mode == .debug {
        webViewProvider.parentView?.addSubview(webView)
      }
    }

//    let request = URLRequest(url: url)
//
//    let configuration = WKWebViewConfiguration()
//    configuration.userContentController.add(self, name: Constants.scriptMessageHandlerName)
//
//    let userScriptWithEventListener = String(format: "window.addEventListener('message', (event) => {if (event.data && event.data.__attentive) {window.webkit.messageHandlers.log.postMessage(event.data.__attentive.action);}}, false);window.addEventListener('visibilitychange', (event) => {window.webkit.messageHandlers.log.postMessage(`%@ ${document.hidden}`);}, false);", Constants.visibilityEvent)
//    let userScript = WKUserScript(source: userScriptWithEventListener, injectionTime: .atDocumentStart, forMainFrameOnly: false)
//    configuration.userContentController.addUserScript(userScript)
//    //TODO Change this to resize to actual content size after it loads
//    //webViewProvider.webView = WKWebView(frame: CGRect(x: view.frame.origin.x, y: view.frame.height / 2, width: view.frame.width, height: view.frame.height / 2), configuration: configuration)
//
//    //let tempFrame = CGRect(x: 0, y: 0, width: view.frame.width, height: 1)
//    //webViewProvider.webView = WKWebView(frame: tempFrame, configuration: configuration)
//
    // Create container view to hold the webview
    let containerView = UIView()
    containerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(containerView)
    webViewProvider.containerView = containerView

    NSLayoutConstraint.activate([
        containerView.topAnchor.constraint(equalTo: view.topAnchor),
        containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        containerView.heightAnchor.constraint(equalTo: view.heightAnchor)
    ])
//
//    // Now create and add the webview
//    let webView = WKWebView(frame: .zero, configuration: configuration)
//    webView.translatesAutoresizingMaskIntoConstraints = false
//    containerView.addSubview(webView)
//
//    NSLayoutConstraint.activate([
//        webView.topAnchor.constraint(equalTo: containerView.topAnchor),
//        webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//        webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
//        webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
//    ])
//
//    webViewProvider.webView = webView
//
//
//    guard let webView = webViewProvider.webView else { return }
//
//    webView.navigationDelegate = self
//    webView.load(request)
//
//    if mode == .debug {
//      webViewProvider.parentView?.addSubview(webView)
//    } else {
//      // In production mode, add the web view using Auto Layout:
//      if self.mode == .production, let parent = webViewProvider.parentView {
//          // Remove any previous instance if needed.
//          webView.removeFromSuperview()
//          parent.addSubview(webView)
//        webView.backgroundColor = .blue
//          webView.translatesAutoresizingMaskIntoConstraints = false
//          // Set initial constraints: center the web view and give it the parent’s full size as a placeholder.
//          NSLayoutConstraint.activate([
//            webView.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
//            webView.centerYAnchor.constraint(equalTo: parent.centerYAnchor)
//          ])
//          // Create and store width and height constraints (initially with the parent's dimensions)
//          self.creativeWidthConstraint = webView.widthAnchor.constraint(equalToConstant: parent.bounds.width)
//          self.creativeHeightConstraint = webView.heightAnchor.constraint(equalToConstant: parent.bounds.height)
//          NSLayoutConstraint.activate([
//            self.creativeWidthConstraint!,
//            self.creativeHeightConstraint!
//          ])
//      }
//      //webViewProvider.webView?.removeFromSuperview()
//      //webView.isOpaque = false
//       //
//      //yes this is where the bug is, this webview was the debug json output and in production we made it clear/invisible. in reality we should not add this in production - we need to resize the entire webview to the actual creative size.
//    }
  }

  func closeCreative() {
    webViewProvider?.webView?.removeFromSuperview()
    webViewProvider?.webView = nil

    isCreativeOpen = false
    webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.closed)
    Loggers.creative.debug("Successfully closed creative")
  }

  func checkAndResize(webView: WKWebView, retryCount: Int = 0) {
    let getSizeJS = """
    (function() {
      var creative = document.getElementById('attentive_creative');
      if (creative) {
        var rect = creative.getBoundingClientRect();
        return JSON.stringify({ x: rect.x, y: rect.y, width: rect.width, height: rect.height });
      } else {
        return JSON.stringify({ width: document.body.scrollWidth, height: document.body.scrollHeight });
      }
    })();
    """

    webView.evaluateJavaScript(getSizeJS) { [weak self] result, error in
      guard let self = self,
            let jsonString = result as? String,
            let data = jsonString.data(using: .utf8),
            let frameDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: CGFloat],
            let x = frameDict["x"],
            let y = frameDict["y"],
            let width = frameDict["width"],
            let height = frameDict["height"] else {
        Loggers.creative.error("Failed to parse creative size.")
        self?.webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
        return
      }

      // If the height is still zero and we haven't exceeded a retry limit, try again later.
      if height == 0 && retryCount < 5 {
        Loggers.creative.debug("Creative height is 0, retrying... (attempt \(retryCount + 1))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self.checkAndResize(webView: webView, retryCount: retryCount + 1)
        }
        return
      }

            DispatchQueue.main.async {
      //        // Update the web view's constraints or frame using the retrieved width and height.
      //        // For example, if using Auto Layout constraints:
              //self.creativeWidthConstraint = webView.widthAnchor.constraint(equalToConstant: width)
              //self.creativeHeightConstraint = webView.heightAnchor.constraint(equalToConstant: height)
              self.webViewProvider?.parentView?.layoutIfNeeded()
              Loggers.creative.debug("creative x = \(x), y = \(y)")
              Loggers.creative.debug("Resized creative to: width=\(width), height=\(height)")
              // Update Auto Layout constraints if using them; otherwise, update the frame.
              if let container = self.webViewProvider?.containerView,
                       let widthConstraint = self.creativeWidthConstraint,
                       let heightConstraint = self.creativeHeightConstraint {
                      widthConstraint.constant = width
                      heightConstraint.constant = height
                let centerX = webView.centerXAnchor.constraint(equalTo: container.centerXAnchor)
                      let centerY = webView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
                      NSLayoutConstraint.activate([centerX, centerY, self.creativeWidthConstraint!, self.creativeHeightConstraint!])
                      container.layoutIfNeeded()
                    } else {
                      // Remove any constraints that might interfere
                        webView.removeConstraints(webView.constraints)
                        // Disable Auto Layout for the web view
                        webView.translatesAutoresizingMaskIntoConstraints = true
                        // Set the frame manually
                        webView.frame = CGRect(x: x, y: y, width: width, height: height)

                        // Optionally, trigger a layout update on the parent view.
                        webView.superview?.setNeedsLayout()
                        webView.superview?.layoutIfNeeded()

                        Loggers.creative.debug("Set creative frame to: x=\(x), y=\(y), width=\(width), height=\(height)")
                      self.webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.opened)
                    }
                    Loggers.creative.debug("Resized creative to: width=\(width), height=\(height)")
              self.webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.opened)
            }

//      DispatchQueue.main.async {
//              // Optionally, adjust x and y relative to your parent view if needed.
//              webView.frame = CGRect(x: x, y: y, width: width, height: height)
//              Loggers.creative.debug("Set creative frame to: x=\(x), y=\(y), width=\(width), height=\(height)")
//        self.webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.opened)
//            }
    }
  }
}

extension ATTNWebViewHandler: WKNavigationDelegate {
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard #available(iOS 14.0, *) else { return }

    let asyncWaitForIframeJS =
      """
      var p = new Promise(resolve => {
          var timeoutHandle = null;
          const interval = setInterval(function() {
              let e = document.querySelector('iframe');
              if (e && e.id === 'attentive_creative') {
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
      asyncWaitForIframeJS,
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
        Loggers.creative.debug("Found creative iframe, resizing WebView.")

//        let getSizeJS =
//              """
//              (function() {
//                  var creative = document.getElementById('attentive_creative');
//                  if (creative) {
//                      var rect = creative.getBoundingClientRect();
//                      return JSON.stringify({ width: rect.width, height: rect.height });
//                  } else {
//                      return JSON.stringify({ width: document.body.scrollWidth, height: document.body.scrollHeight });
//                  }
//              })();
//              """

//        webView.evaluateJavaScript(getSizeJS) { result, error in
//          guard let jsonString = result as? String,
//                let data = jsonString.data(using: .utf8),
//                let sizeDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: CGFloat],
//                let height = sizeDict["height"],
//                let width = sizeDict["width"] else {
//            Loggers.creative.error("Failed to parse height from creative.")
//            webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
//            return
//          }
//
//          DispatchQueue.main.async {
//            guard let container = webViewProvider.containerView else {
//              Loggers.creative.error("Container view not found.")
//              return
//            }
//
//            if let widthConstraint = self.creativeWidthConstraint,
//                     let heightConstraint = self.creativeHeightConstraint {
//                    widthConstraint.constant = width
//                    heightConstraint.constant = height
//                  }
//                  self.webViewProvider?.parentView?.layoutIfNeeded()
//                  Loggers.creative.debug("Resized creative to: width=\(width), height=\(height)")
//
//            // Add to parent if not already added
//            if self.mode == .production,
//               let parent = webViewProvider.parentView,
//               container.superview == nil {
//              parent.addSubview(container)
//            }
//
//            webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.opened)
//          }
//        }
        self.checkAndResize(webView: webView)
      case .timeout:
        Loggers.creative.error("Creative timed out. Not showing WebView.")
        webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)

      case .unknown(let statusString):
        Loggers.creative.error("Unknown iframe status: \(statusString)")
        webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)

      default:
        break
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
    Loggers.creative.debug("Web event message: \(messageBody). isCreativeOpen: \(self.isCreativeOpen ? "YES" : "NO")")

    if messageBody == "CLOSE" {
      closeCreative()
    } else if messageBody == "IMPRESSION" {
      Loggers.creative.debug("Creative opened and generated impression event")
      isCreativeOpen = true
    } else if messageBody == String(format: "%@ true", Constants.visibilityEvent), isCreativeOpen {
      Loggers.creative.debug("Nav away from creative, closing")
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

  var isCreativeOpen: Bool {
    get { webViewProvider?.isCreativeOpen ?? false }
    set { webViewProvider?.isCreativeOpen = newValue }
  }
}
