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
    label.font = UIFont.systemFont(ofSize: 16)
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

  private let devicetokenLabel: UILabel = {
    let devicetokenLabel = UILabel()
    let savedDeviceToken = UserDefaults.standard.string(forKey: "deviceToken")
    devicetokenLabel.text = "Device Token: \(savedDeviceToken ?? "Not saved")"
    devicetokenLabel.font = UIFont.systemFont(ofSize: 10)
    devicetokenLabel.textColor = .darkGray
    devicetokenLabel.numberOfLines = 0
    return devicetokenLabel
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Settings"
    view.backgroundColor = .white

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
    // TODO: Add back stackView.addArrangedSubview(identifyUserButton)
    stackView.addArrangedSubview(clearUserButton)
    stackView.addArrangedSubview(clearCookiesButton)
    stackView.addArrangedSubview(devicetokenLabel)

    // copy device token button
    let copyButton = UIButton(type: .system)
    copyButton.setTitle("Copy Device Token", for: .normal)
    copyButton.titleLabel?.font = .systemFont(ofSize: 14)
    copyButton.addTarget(self, action: #selector(copyDeviceTokenTapped), for: .touchUpInside)
    stackView.addArrangedSubview(copyButton)

    view.layer.backgroundColor = UIColor(red: 1, green: 0.773, blue: 0.725, alpha: 1).cgColor
  }

  // MARK: - Actions Setup

  private func setupActions() {
    switchAccountButton.addTarget(self, action: #selector(switchAccountTapped), for: .touchUpInside)
    manageAddressesButton.addTarget(self, action: #selector(manageAddressesTapped), for: .touchUpInside)
    showCreativeButton.addTarget(self, action: #selector(showCreativeTapped), for: .touchUpInside)
    showPushPermissionButton.addTarget(self, action: #selector(showPushPermissionTapped), for: .touchUpInside)
    sendPushTokenButton.addTarget(self, action: #selector(didTapSendPushTokenButton), for: .touchUpInside
      )
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
      showToast(with: "No device token found")
      return
    }
    self.getAttentiveSdk().registerDeviceToken(tokenData)
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
      showToast(with: "No device token found")
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

}
