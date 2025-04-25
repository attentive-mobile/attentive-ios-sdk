//
//  DebugConsoleViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/17/25.
//

import UIKit

class DebugConsoleViewController: UIViewController {

  // A text view that displays the debug log.
  private let textView: UITextView = {
    let tv = UITextView()
    tv.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    tv.isEditable = false
    tv.translatesAutoresizingMaskIntoConstraints = false
    return tv
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white

    view.alpha = 0.8

    setupUI()
    setupNavigationItems()
  }

  private func setupUI() {
    view.addSubview(textView)
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: view.topAnchor),
      textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    // Sample log text.
    textView.text = """
        Debug Log:
        - Init ATTNSDKFramework v1.0.2, Mode: debug
        - Obtained existing visitor id: 4212D563311F4CDFA3669A9CF6D4C32C
        - Created User Agent: AttentiveExample/1.0.2 (iPhone; iOS Version 18.2 ...)
        - ... (more log output)
        """
  }

  private func setupNavigationItems() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                       target: self,
                                                       action: #selector(closeTapped))
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action,
                                                        target: self,
                                                        action: #selector(shareButtonTapped))
  }

  @objc private func closeTapped() {
    dismiss(animated: true, completion: nil)
  }

  @objc private func shareButtonTapped() {
    let debugText = textView.text ?? "No debug logs available"
    let activityVC = UIActivityViewController(activityItems: [debugText], applicationActivities: nil)

    // For iPad compatibility
    activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
    present(activityVC, animated: true, completion: nil)
  }
}
