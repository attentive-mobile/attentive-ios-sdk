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
        completionHandler?(openResult)
    }
}
