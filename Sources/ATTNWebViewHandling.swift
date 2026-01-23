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

        let userScriptWithEventListener = #"window.addEventListener('message', function(event) { if (event.data && event.data.__attentive) { window.webkit.messageHandlers.log.postMessage(event.data.__attentive); } }, false); window.addEventListener('visibilitychange', function(event) { window.webkit.messageHandlers.log.postMessage("\#(Constants.visibilityEvent) " + document.hidden); }, false);"#
        let userScript = WKUserScript(source: userScriptWithEventListener, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
        let webView = CustomWebView(frame: .zero, configuration: configuration)
        webView.onRemovedFromWindow = { [weak self] in
            // Only close if the creative is currently open.
            if let strongSelf = self, strongSelf.stateManager.getState() != .closed {
                strongSelf.closeCreative()
            }
        }
        return webView
    }

    func launchCreative(
        parentView view: UIView,
        creativeId: String? = nil,
        handler: ATTNCreativeTriggerCompletionHandler? = nil
    ) {
        let creativeIdLog = creativeId ?? "default"
        Loggers.creative.debug("Launching creative - Visitor ID: \(self.userIdentity.visitorId), Creative ID: \(creativeIdLog), Domain: \(self.domain)")

        guard stateManager.compareAndSet(from: .closed, to: .launching) else {
            Loggers.creative.debug("Attempted to trigger creative, but creative is already launching or open. Taking no action - Visitor ID: \(self.userIdentity.visitorId)")
            return
        }

        creativeQueue.async { [weak self] in
            guard let self = self else { return }
            guard let webViewProvider = self.webViewProvider else {
                Loggers.creative.error("Cannot show creative: webViewProvider is nil - Visitor ID: \(self.userIdentity.visitorId)")
                return
            }

            webViewProvider.parentView = view
            webViewProvider.triggerHandler = handler

            Loggers.creative.debug("Showing creative - Visitor ID: \(self.userIdentity.visitorId), Domain: \(self.domain, privacy: .public)")

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
                Loggers.creative.error("Failed to create URL from creative page URL string - Visitor ID: \(self.userIdentity.visitorId), URL String: \(creativePageUrl)")
                stateManager.updateState(.closed)
                return
            }

            Loggers.creative.debug("Setting up WebView for creative - Visitor ID: \(self.userIdentity.visitorId)")

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let request = URLRequest(url: url)
                let configuration = WKWebViewConfiguration()
                configuration.userContentController.add(self, name: Constants.scriptMessageHandlerName)

                let userScriptWithEventListener = String(format: "window.addEventListener('message', (event) => {if (event.data && event.data.__attentive) {window.webkit.messageHandlers.log.postMessage(event.data.__attentive.action);}}, false);window.addEventListener('visibilitychange', (event) => {window.webkit.messageHandlers.log.postMessage(`%@ ${document.hidden}`);}, false);", Constants.visibilityEvent)
                let userScript = WKUserScript(source: userScriptWithEventListener, injectionTime: .atDocumentStart, forMainFrameOnly: false)
                configuration.userContentController.addUserScript(userScript)
                // Prevent dupes
                if let existingWebView = webViewProvider.webView {
                    DispatchQueue.main.async {
                        existingWebView.removeFromSuperview()
                        existingWebView.stopLoading()
                    }
                    webViewProvider.webView = nil
                }
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let webView = self.webViewProvider?.webView {
                webView.navigationDelegate = nil
                webView.removeFromSuperview()
                webView.stopLoading()
                webView.configuration.userContentController.removeAllUserScripts()
                webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.scriptMessageHandlerName)
            }
            self.webViewProvider?.webView = nil
        }

        creativeQueue.async { [weak self] in
            guard let self = self else { return }
            stateManager.updateState(.closed)
            self.webViewProvider?.triggerHandler?(ATTNCreativeTriggerStatus.closed)
            Loggers.creative.debug("Successfully closed creative - Visitor ID: \(self.userIdentity.visitorId)")
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
            Loggers.creative.error("Navigation policy decision: URL is nil, canceling navigation - Visitor ID: \(self.userIdentity.visitorId)")
            decisionHandler(.cancel)
            return
        }

        if url.scheme == "sms" {
            Loggers.creative.debug("Opening SMS URL externally: \(url) - Visitor ID: \(self.userIdentity.visitorId)")
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            if navigationAction.targetFrame == nil {
                Loggers.creative.debug("Opening URL in external browser (no target frame): \(url) - Visitor ID: \(self.userIdentity.visitorId)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                Loggers.creative.debug("Allowing navigation to URL: \(url) - Visitor ID: \(self.userIdentity.visitorId)")
                decisionHandler(.allow)
            }
        } else {
            Loggers.creative.debug("Allowing navigation with scheme: \(url.scheme ?? "unknown") - Visitor ID: \(self.userIdentity.visitorId)")
            decisionHandler(.allow)
        }
    }
}

extension ATTNWebViewHandler: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let messageBody = message.body as? String ?? "Empty"
        Loggers.creative.debug("Web event message: \(messageBody). is creative open: \(self.stateManager.getState() == .open ? "YES" : "NO")")

        if messageBody == "CLOSE" {
            closeCreative()
            return
        }

        guard let parent = self.webViewProvider?.parentView else { return }

        guard let body = message.body as? [String: Any],
                    let action = body["action"] as? String else {
            return
        }

        switch action {
        case "CLOSE":
            closeCreative()

        case "IMPRESSION":
            stateManager.updateState(.open)
            Loggers.creative.debug("Creative opened and generated impression event")

        case String(format: "%@ true", Constants.visibilityEvent)
            where stateManager.getState() == .open:
            Loggers.creative.debug("document-visibility: true — suppressing premature closure")

        case "RESIZE_FRAME":
            guard let style = body["style"] as? [String: Any] else {
                Loggers.creative.debug("RESIZE_FRAME received but style missing.")
                return
            }

            func parsePx(_ value: String?) -> CGFloat? {
                guard let str = value?.trimmingCharacters(in: .whitespaces),
                            str.hasSuffix("px"),
                            let doubleValue = Double(str.replacingOccurrences(of: "px", with: "")) else {
                    return nil
                }
                return CGFloat(doubleValue)
            }

            guard let width = parsePx(style["width"] as? String),
                        let height = parsePx(style["height"] as? String),
                        let left = parsePx(style["left"] as? String),
                        let bottom = parsePx(style["bottom"] as? String) else {
                Loggers.creative.debug("RESIZE_FRAME style has non-px or missing values. Defaulting to fullscreen.")
                let fallbackArea = UIScreen.main.bounds
                DispatchQueue.main.async {
                    if let customWebView = self.webViewProvider?.webView as? CustomWebView {
                        customWebView.updateInteractiveHitArea(fallbackArea)
                        Loggers.creative.debug("Creative interactive area updated to fullscreen fallback: \(fallbackArea.width)x\(fallbackArea.height)")
                    }
                }
                return
            }

            let safeFrame = parent.safeAreaLayoutGuide.layoutFrame
            let flippedY = safeFrame.maxY - bottom - height
            let adjustedX = safeFrame.minX + left
            let newArea = CGRect(x: adjustedX, y: flippedY, width: width, height: height)

            // 100 is a magic number that helps determine if a creative is full screen
            let isFullscreen = height >= 100
            Loggers.creative.debug("Resizing creative to \(isFullscreen ? "fullscreen" : "bubble")")

            DispatchQueue.main.async {
                if let customWebView = self.webViewProvider?.webView as? CustomWebView {
                    customWebView.updateInteractiveHitArea(newArea)
                    Loggers.creative.debug("Creative interactive area updated to: x: \(newArea.minX), y: \(newArea.minY), width: \(newArea.width), height: \(newArea.height)")
                }
            }

        default:
            break
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
/// Web view with custom hit area where only touches inside the interactive area are handled. This allows users to interact with rest of the app when creative is minimized to a bubble; also calls a closure when it is removed from its window to detect when it's no longer on screen.
class CustomWebView: WKWebView {

    var interactiveHitArea: CGRect = .zero {
        didSet {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }

    var onRemovedFromWindow: (() -> Void)?
    var lastKnownHitArea: CGRect = .zero

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        setupLifecycleObserver()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLifecycleObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleDidBecomeActive() {
        updateScrollBehavior()
        Loggers.creative.debug("handleDidBecomeActive: lastKnownHitArea width and height: \(self.lastKnownHitArea.width)x\(self.lastKnownHitArea.height)")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func updateInteractiveHitArea(_ newArea: CGRect) {
        interactiveHitArea = newArea
        lastKnownHitArea = newArea
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return interactiveHitArea.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if interactiveHitArea.contains(point) {
            return super.hitTest(point, with: event)
        }
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Ensure gesture state remains consistent across navigation stack transitions
        updateScrollBehavior()

        // If the web view's window becomes nil, it's no longer on screen.
        if self.window == nil {
            onRemovedFromWindow?()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateScrollBehavior()
    }

    private func updateScrollBehavior() {
        let shouldReceiveTouches = !interactiveHitArea.isEmpty && bounds.intersects(interactiveHitArea)

        scrollView.isScrollEnabled = shouldReceiveTouches
        scrollView.isUserInteractionEnabled = shouldReceiveTouches

        // Disable/enable gesture recognizers based on current active area
        scrollView.gestureRecognizers?.forEach { $0.isEnabled = shouldReceiveTouches }
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
}

extension UIView {
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

