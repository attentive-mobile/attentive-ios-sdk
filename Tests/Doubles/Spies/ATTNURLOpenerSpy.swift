//
//  ATTNURLOpenerSpy.swift
//  attentive-ios-sdk-framework
//
//  Created by Umair Sharif on 7/24/26.
//

import UIKit
@testable import ATTNSDKFramework

final class ATTNURLOpenerSpy: ATTNURLOpening {
    private(set) var openWasCalled = false
    private(set) var openedURLs: [URL] = []
    private(set) var lastOptions: [UIApplication.OpenExternalURLOptionsKey: Any] = [:]

    var openResult = true

    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler: ((Bool) -> Void)?) {
        openWasCalled = true
        openedURLs.append(url)
        lastOptions = options
        // Match the real opener's timing: `UIApplication.open`'s completion arrives on a later
        // runloop turn, never synchronously. A synchronous callback here would let tests pass
        // on ordering assumptions the production path doesn't guarantee.
        if let completionHandler {
            DispatchQueue.main.async { completionHandler(self.openResult) }
        }
    }
}
