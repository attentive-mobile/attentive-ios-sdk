//
//  UIViewController+Toast.swift
//  AttentiveExample
//
//  Created by Adela Gao on 4/3/25.
//

import UIKit

extension UIViewController {
    func showToast(with message: String, duration: TimeInterval = 1.0) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            alert.dismiss(animated: true)
        }
    }
}
