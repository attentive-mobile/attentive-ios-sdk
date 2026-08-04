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

        static func getRawValue(from value: Any) -> Self? {
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

    // Internal (rather than private) so tests can drive alternate paths via subclasses.
    weak var webViewProvider: ATTNWebViewProviding?
    private var urlBuilder: ATTNCreativeUrlProviding
    // a serial dispatch queue to synchronize access to webview to prevent race condition
    private let creativeQueue = DispatchQueue(label: "com.attentive.creativeQueue")
    private let stateManager: ATTNCreativeStateManager
    // Minimized creative's frame (when creative is minimized to a bubble instead of full screen)
    private(set) var minimizedFrame: CGRect?
    func updateMinimizedFrame(_ frame: CGRect) {
        minimizedFrame = frame
    }

    // Guards the two timeout paths (native launching timeout and JS iframe-detection timeout)
    // so they don't both fire .notOpened or both attempt teardown when they race.
    private var didTimeOut: Bool = false

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
            guard let self = self else { return }
            switch self.stateManager.getState() {
            case .closed:
                return
            case .launching:
                // Host detached the parent view mid-launch. Report .notOpened and
                // clean up rather than emitting .closed for a creative that never
                // opened.
                guard let webViewProvider = self.webViewProvider else { return }
                self.reportNotOpenedAndTearDown(webViewProvider: webViewProvider, reason: "parent view removed from window during launch")
            case .open:
                self.closeCreative()
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
        Loggers.creative.debug("Launching creative - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Creative ID: \(creativeIdLog, privacy: .public), Domain: \(self.domain, privacy: .public)")

        guard stateManager.compareAndSet(from: .closed, to: .launching) else {
            Loggers.creative.debug("Attempted to trigger creative, but creative is already launching or open. Taking no action - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
            return
        }

        didTimeOut = false

        creativeQueue.async { [weak self] in
            guard let self = self else { return }
            guard let webViewProvider = self.webViewProvider else {
                Loggers.creative.error("Cannot show creative: webViewProvider is nil - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
                return
            }

            webViewProvider.parentView = view
            webViewProvider.triggerHandler = handler

            Loggers.creative.debug("Showing creative - Visitor ID: \(self.userIdentity.visitorId), Domain: \(self.domain, privacy: .public)")

            // Time out logic in case creative doesn't launch
            let timeoutInterval: TimeInterval = 5.0
            creativeQueue.asyncAfter(deadline: .now() + timeoutInterval) { [weak self] in
                guard let self = self, let webViewProvider = self.webViewProvider else { return }
                guard self.stateManager.getState() == .launching, !self.didTimeOut else { return }
                self.didTimeOut = true
                Loggers.creative.error("Creative launch timed out.")
                DispatchQueue.main.async {
                    webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
                }
                self.tearDownWebView()
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

            Loggers.creative.debug("Requesting creative page url: \(creativePageUrl, privacy: .public)" )

            guard let url = URL(string: creativePageUrl) else {
                Loggers.creative.error("Failed to create URL from creative page URL string - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), URL String: \(creativePageUrl, privacy: .public)")
                stateManager.updateState(.closed)
                return
            }

            Loggers.creative.debug("Setting up WebView for creative - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let request = URLRequest(url: url)
                let configuration = WKWebViewConfiguration()
                configuration.userContentController.add(self, name: Constants.scriptMessageHandlerName)

                let jsEventListeners =
                    "window.addEventListener('message', (event) => {" +
                    "if (event.data && event.data.__attentive) {" +
                    "window.webkit.messageHandlers.log.postMessage(" +
                    "event.data.__attentive.action);}}, false);" +
                    "window.addEventListener('visibilitychange', (event) => {" +
                    "window.webkit.messageHandlers.log.postMessage(" +
                    "`%@ ${document.hidden}`);}, false);"
                let userScriptWithEventListener = String(
                    format: jsEventListeners,
                    Constants.visibilityEvent
                )
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
            Loggers.creative.debug("Successfully closed creative - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
        }
    }

    /// Fires `.notOpened` once (guarded by `didTimeOut` so a racing native timeout
    /// doesn't double-fire) and then tears down the WebView. `reason` is only logged
    /// when this call wins the race — losers stay silent to avoid misleading "second
    /// timeout" log lines after teardown has already started.
    private func reportNotOpenedAndTearDown(webViewProvider: ATTNWebViewProviding, reason: String) {
        guard !didTimeOut else { return }
        didTimeOut = true
        Loggers.creative.error("Creative not opened: \(reason, privacy: .public)")
        DispatchQueue.main.async {
            webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
        }
        tearDownWebView()
    }

    /// Tears down the WebView without firing the trigger handler. Called by timeout paths
    /// that have already reported `.notOpened` to the handler; we must not additionally
    /// emit `.closed`, which `closeCreative()` would do.
    private func tearDownWebView() {
        // Weak-capture the target webview + its parent so the post-teardown log can
        // check whether the view is really detached from the hierarchy Target's app
        // sees, not just nil'd on the provider.
        weak var tornDownWebView: WKWebView? = webViewProvider?.webView
        weak var tornDownParent: UIView? = webViewProvider?.parentView

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let webView = self.webViewProvider?.webView else {
                self.webViewProvider?.webView = nil
                return
            }
            Loggers.creative.debug("Timeout teardown starting — attached=\(webView.superview != nil ? "YES" : "NO", privacy: .public), isLoading=\(webView.isLoading ? "YES" : "NO", privacy: .public)")
            webView.navigationDelegate = nil
            webView.removeFromSuperview()
            webView.stopLoading()
            webView.configuration.userContentController.removeAllUserScripts()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.scriptMessageHandlerName)
            self.webViewProvider?.webView = nil
        }

        creativeQueue.async { [weak self] in
            self?.stateManager.updateState(.closed)
        }

        // Post-teardown verification: runs after the main-queue teardown block above.
        // If this ever logs FAIL, the WebView is leaking somewhere and we have a bug.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let providerCleared = (self.webViewProvider?.webView == nil)
            let stillAttached: Bool = {
                guard let target = tornDownWebView, let parent = tornDownParent else { return false }
                return parent.subviews.contains(target)
            }()
            let stateName: String = {
                switch self.stateManager.getState() {
                case .closed: return "closed"
                case .launching: return "launching"
                case .open: return "open"
                }
            }()
            let passed = providerCleared && !stillAttached
            Loggers.creative.debug("Timeout teardown \(passed ? "PASS" : "FAIL", privacy: .public) — providerCleared=\(providerCleared ? "YES" : "NO", privacy: .public), stillAttachedToParent=\(stillAttached ? "YES" : "NO", privacy: .public), state=\(stateName, privacy: .public)")
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
                self.reportNotOpenedAndTearDown(webViewProvider: webViewProvider, reason: "no status returned from JS")
                return
            }

            switch ScriptStatus.getRawValue(from: statusAny) {
            case .success:
                Loggers.creative.debug("Found creative iframe, showing WebView.")
                // Transition out of .launching so the native 5s timeout can't tear
                // down a successfully-rendered creative in the window between
                // .opened firing and IMPRESSION arriving.
                self.stateManager.compareAndSet(from: .launching, to: .open)
                webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.opened)
            case .timeout:
                self.reportNotOpenedAndTearDown(webViewProvider: webViewProvider, reason: "JS iframe-detection timed out")
            case .unknown(let statusString):
                self.reportNotOpenedAndTearDown(webViewProvider: webViewProvider, reason: "unknown JS status: \(statusString)")
            default: break
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let webViewProvider = self.webViewProvider else { return }
        reportNotOpenedAndTearDown(webViewProvider: webViewProvider, reason: "navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let webViewProvider = self.webViewProvider else { return }
        reportNotOpenedAndTearDown(webViewProvider: webViewProvider, reason: "provisional navigation failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let webViewProvider = self.webViewProvider else { return }
        reportNotOpenedAndTearDown(webViewProvider: webViewProvider, reason: "WebContent process terminated (likely OOM/jetsam)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            Loggers.creative.error("Navigation policy decision: URL is nil, canceling navigation - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
            decisionHandler(.cancel)
            return
        }

        if url.scheme == "sms" {
            Loggers.creative.debug("Opening SMS URL externally: \(url, privacy: .public) - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            if navigationAction.targetFrame == nil {
                Loggers.creative.debug("Opening URL in external browser (no target frame): \(url, privacy: .public) - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                Loggers.creative.debug("Allowing navigation to URL: \(url, privacy: .public) - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
                decisionHandler(.allow)
            }
        } else {
            Loggers.creative.debug("Allowing navigation with scheme: \(url.scheme ?? "unknown", privacy: .public) - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
            decisionHandler(.allow)
        }
    }
}

extension ATTNWebViewHandler: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let messageBody = message.body as? String ?? "Empty"
        Loggers.creative.debug("Web event message: \(messageBody, privacy: .public). is creative open: \(self.stateManager.getState() == .open ? "YES" : "NO", privacy: .public)")

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
                        Loggers.creative.debug("Creative interactive area updated to fullscreen fallback: \(fallbackArea.width, privacy: .public)x\(fallbackArea.height, privacy: .public)")
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
            Loggers.creative.debug("Resizing creative to \(isFullscreen ? "fullscreen" : "bubble", privacy: .public)")

            DispatchQueue.main.async {
                if let customWebView = self.webViewProvider?.webView as? CustomWebView {
                    customWebView.updateInteractiveHitArea(newArea)
                    Loggers.creative.debug("Creative interactive area updated to: x: \(newArea.minX, privacy: .public), y: \(newArea.minY, privacy: .public), width: \(newArea.width, privacy: .public), height: \(newArea.height, privacy: .public)")
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
        Loggers.creative.debug("handleDidBecomeActive: lastKnownHitArea width and height: \(self.lastKnownHitArea.width, privacy: .public)x\(self.lastKnownHitArea.height, privacy: .public)")
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
