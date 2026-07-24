//
//  ATTNURLOpening.swift
//  attentive-ios-sdk-framework
//
//  Created by Umair Sharif on 7/24/26.
//

import UIKit

/// Abstraction over `UIApplication`'s URL opening so deep-link handling can be unit tested.
protocol ATTNURLOpening {
    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler: ((Bool) -> Void)?)
}

/// Default `ATTNURLOpening` backed by `UIApplication.shared`.
struct ATTNApplicationURLOpener: ATTNURLOpening {
    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler: ((Bool) -> Void)?) {
        Task { @MainActor in
            UIApplication.shared.open(url, options: options, completionHandler: completionHandler)
        }
    }
}
