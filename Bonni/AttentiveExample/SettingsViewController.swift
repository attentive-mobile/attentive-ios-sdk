//
//  SettingsViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/24/25.
//

import UIKit
import ATTNSDKFramework
import WebKit
import os.log

class SettingsViewController: UIViewController {

  // MARK: - UI Components

  private let scrollView: UIScrollView = {
    let scrollView = UIScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    return scrollView
  }()

  private let contentView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let stackView: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 16
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  // MARK: - Account Info Section

  private let accountInfoLabel: UILabel = {
    let label = UILabel()
    label.text = "Login Info: Guest"  // Update this based on your current login info.
    label.font = UIFont(name: "DegularDisplay-Regular", size: 16)
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let switchAccountButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Switch Account / Log Out", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let manageAddressesButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Manage Addresses", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  // MARK: - Test Events Section

  private let showCreativeButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Show Creative", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let showPushPermissionButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Show Push Permission", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let sendPushTokenButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Send Push Token", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let sendAppOpenEventsButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Send App Open Events", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let identifyUserButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Identify User", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let clearUserButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Clear User", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let clearCookiesButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Clear Cookies", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let copyDeviceTokenButton: UIButton = {
    let copyButton = UIButton(type: .system)
    copyButton.setTitle("Copy Device Token", for: .normal)
    copyButton.addTarget(self, action: #selector(copyDeviceTokenTapped), for: .touchUpInside)
    return copyButton
  }()

  private let devicetokenLabel: UILabel = {
    let devicetokenLabel = UILabel()
    let savedDeviceToken = UserDefaults.standard.string(forKey: "deviceToken")
    devicetokenLabel.text = "Device Token: \(savedDeviceToken ?? "Not saved")"
    devicetokenLabel.font = UIFont(name: "DegularDisplay-Regular", size: 16)
    devicetokenLabel.textColor = .darkGray
    devicetokenLabel.numberOfLines = 0
    return devicetokenLabel
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Settings"
    view.backgroundColor = .white
    scrollView.backgroundColor = .white
    contentView.backgroundColor = .white
    if let navBar = navigationController?.navigationBar {
      navBar.barTintColor = UIColor(red: 1, green: 0.773, blue: 0.725, alpha: 1)
      navBar.isTranslucent = false
      // navBar.titleTextAttributes = [.foregroundColor: UIColor.white] // if you want white title text
    }

    setupUI()
    setupActions()
    setupObservers()
  }

  // MARK: - UI Setup

  private func setupUI() {
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(stackView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
    ])

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
      stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
    ])

    stackView.addArrangedSubview(accountInfoLabel)
    stackView.addArrangedSubview(switchAccountButton)
    stackView.addArrangedSubview(manageAddressesButton)

    let divider = UIView()
    divider.backgroundColor = .lightGray
    divider.translatesAutoresizingMaskIntoConstraints = false
    divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
    stackView.addArrangedSubview(divider)

    stackView.addArrangedSubview(showCreativeButton)
    stackView.addArrangedSubview(showPushPermissionButton)
    stackView.addArrangedSubview(sendPushTokenButton)
    stackView.addArrangedSubview(sendAppOpenEventsButton)
    // TODO: Add back stackView.addArrangedSubview(identifyUserButton)
    stackView.addArrangedSubview(clearUserButton)
    stackView.addArrangedSubview(clearCookiesButton)
    stackView.addArrangedSubview(devicetokenLabel)
    stackView.addArrangedSubview(copyDeviceTokenButton)

    if let degular = UIFont(name: "DegularDisplay-Regular", size: 16) {
      let allButtons: [UIButton] = [
        switchAccountButton,
        manageAddressesButton,
        showCreativeButton,
        showPushPermissionButton,
        sendPushTokenButton,
        identifyUserButton,
        clearUserButton,
        clearCookiesButton,
        copyDeviceTokenButton
      ]
      allButtons.forEach {
        $0.titleLabel?.font = degular
        $0.titleLabel?.tintColor = .black
      }
    }
  }

  // MARK: - Actions Setup

  private func setupActions() {
    switchAccountButton.addTarget(self, action: #selector(switchAccountTapped), for: .touchUpInside)
    manageAddressesButton.addTarget(self, action: #selector(manageAddressesTapped), for: .touchUpInside)
    showCreativeButton.addTarget(self, action: #selector(showCreativeTapped), for: .touchUpInside)
    showPushPermissionButton.addTarget(self, action: #selector(showPushPermissionTapped), for: .touchUpInside)
    sendPushTokenButton.addTarget(self, action: #selector(didTapSendPushTokenButton), for: .touchUpInside
      )
    sendAppOpenEventsButton.addTarget(self, action: #selector(sendAppOpenEventsTapped), for: .touchUpInside)
    identifyUserButton.addTarget(self, action: #selector(identifyUserTapped), for: .touchUpInside)
    clearUserButton.addTarget(self, action: #selector(clearUserTapped), for: .touchUpInside)
    clearCookiesButton.addTarget(self, action: #selector(clearCookiesTapped), for: .touchUpInside)
  }

  private func setupObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(deviceTokenUpdated),
      name: NSNotification.Name("DeviceTokenUpdated"),
      object: nil
    )
  }

  // MARK: - Button Actions

  @objc private func switchAccountTapped() {
    let alert = UIAlertController(title: nil, message: "hello world", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(alert, animated: true, completion: nil)
  }

  @objc private func manageAddressesTapped() {
    // TODO: Add logic to manage and edit addresses
  }

  @objc private func showCreativeTapped() {
    self.getAttentiveSdk().trigger(self.view)
  }

  @objc private func showPushPermissionTapped() {
    self.getAttentiveSdk().registerForPushNotifications()
  }

  @objc private func didTapSendPushTokenButton() {
    guard let tokenData = UserDefaults.standard.data(forKey: "deviceTokenData") else {
      showToast(with: "No device token found. Press 'Show Push Permission' button to obtain one.")
      return
    }
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      guard let self = self else { return }
      let authorizationStatus = settings.authorizationStatus
      getAttentiveSdk().registerDeviceToken(tokenData, authorizationStatus: authorizationStatus) { [weak self] data, url, response, error in
        guard let self = self else { return }
        DispatchQueue.main.async {
          var lines: [String] = []
          if let url = url {
            lines.append("URL: \(url.absoluteString)")
          }
          lines.append("Domain: games")
          if let http = response as? HTTPURLResponse {
            lines.append("Status: \(http.statusCode)")
            // Clean up headers to remove "AnyHashable" type name etc for readability
            let headerLines = http.allHeaderFields.compactMap { (key, value) -> String? in
              guard let keyString = key as? String else { return nil }
              return "\(keyString): \(value)"
            }
            if !headerLines.isEmpty {
              lines.append("Headers:\n" + headerLines.joined(separator: "\n"))
            }
          }
          if let d = data, let body = String(data: d, encoding: .utf8), !body.isEmpty {
            lines.append("Body:\n\(body)")
          }
          if let err = error {
            lines.append("Error: \(err.localizedDescription)")
          }
          let message = lines.joined(separator: "\n\n")

          let resultVC = UIViewController()
          resultVC.view.backgroundColor = .systemBackground
          resultVC.preferredContentSize = CGSize(width: 300, height: 400)

          let textView = UITextView()
          textView.text = message
          textView.textAlignment = .left
          textView.isEditable = false
          textView.translatesAutoresizingMaskIntoConstraints = false
          if let customFont = UIFont(name: "DegularDisplay-Regular", size: 16) {
            textView.font = customFont
          }
          resultVC.view.addSubview(textView)
          NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: resultVC.view.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: resultVC.view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: resultVC.view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: resultVC.view.bottomAnchor, constant: -16)
          ])

          let nav = UINavigationController(rootViewController: resultVC)
          resultVC.navigationItem.title = "Push Token Result"
          resultVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(self.shareResult)
          )

          objc_setAssociatedObject(nav, &AssociatedKeys.resultMessage, message, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

          nav.modalPresentationStyle = .formSheet
          self.present(nav, animated: true)
        }
      }
    }

  }

  @objc private func sendAppOpenEventsTapped() {
    guard let token = UserDefaults.standard.string(forKey: "deviceToken") else {
      showToast(with: "No push token available. Skipping registering app events")
      return
    }
    let appLaunchEvents: [[String:Any]] = [
      [
        "ist": "al",
        "data": ["message_id": "0"]
      ]
    ]
    getAttentiveSdk().registerAppEvents(appLaunchEvents, pushToken: "apns:\(token)")
  }

  @objc private func identifyUserTapped() {
    // TODO: Identify the user & show results on debug view
  }

  @objc private func clearUserTapped() {
    // TODO: Clear the user
  }

  @objc private func clearCookiesTapped() {
    os_log("Clearing cookies!")
    WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeCookies],
                                            modifiedSince: Date(timeIntervalSince1970: 0),
                                            completionHandler: { os_log("Cleared cookies!") })
    showToast(with: "Cookies cleared")
  }

  @objc private func copyDeviceTokenTapped() {
    guard let token = UserDefaults.standard.string(forKey: "deviceToken"),
          !token.isEmpty else {
      showToast(with: "No device token found. Press 'Show Push Permission' button to obtain one.")
      return
    }
    UIPasteboard.general.string = token

    showToast(with: "Device token copied")
  }

  private func getAttentiveSdk() -> ATTNSDK {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let sdk = appDelegate.attentiveSdk else {
      fatalError("Could not retrieve attentiveSdk from AppDelegate")
    }
    return sdk
  }

  @objc private func deviceTokenUpdated() {
    updateDeviceTokenLabel()
  }

  private func updateDeviceTokenLabel() {
    let savedDeviceToken = UserDefaults.standard.string(forKey: "deviceToken") ?? "Not saved"
    devicetokenLabel.text = "Device Token: \(savedDeviceToken)"
  }

  // MARK: – Share action

  private struct AssociatedKeys {
    static var resultMessage = "resultMessage"
  }

  @objc private func shareResult(_ sender: UIBarButtonItem) {
    guard
      let nav = presentedViewController as? UINavigationController,
      let message = objc_getAssociatedObject(nav, &AssociatedKeys.resultMessage) as? String
    else { return }

    let activity = UIActivityViewController(activityItems: [message], applicationActivities: nil)
    // For iPad / formSheet compatibility
    activity.popoverPresentationController?.barButtonItem = sender
    nav.present(activity, animated: true)
  }

}
