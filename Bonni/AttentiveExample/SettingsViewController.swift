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
import UserNotifications

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

  private let modifyDomainButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Modify Domain", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let modifyEmailButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Modify Email", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let sendLocalPushNotification: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("🔔 Send Local Push Notification", for: .normal)
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
    let savedDeviceToken = UserDefaults.standard.string(forKey: "deviceTokenForDisplay")
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
    stackView.addArrangedSubview(modifyDomainButton)
    stackView.addArrangedSubview(modifyEmailButton)
    stackView.addArrangedSubview(sendLocalPushNotification)
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
        modifyDomainButton,
        modifyEmailButton,
        showPushPermissionButton,
        sendLocalPushNotification,
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
    modifyDomainButton.addTarget(self, action: #selector(modifyDomainTapped), for: .touchUpInside)
    modifyEmailButton.addTarget(self, action: #selector(modifyEmailTapped), for: .touchUpInside)
    sendLocalPushNotification.addTarget(self, action: #selector(sendLocalPushNotificationTapped), for: .touchUpInside)
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

  // MARK: - New Button Actions
  @objc private func modifyDomainTapped() {
    presentInputAlert(title: "Modify Domain",
                      message: "Enter a new domain",
                      placeholder: "",
                      kind: .domain)
  }

  @objc private func modifyEmailTapped() {
    presentInputAlert(title: "Modify Email",
                      message: "Enter a new email",
                      placeholder: "name@example.com",
                      kind: .email)
  }

  // MARK: - Input Alert + Validation
  private enum InputKind { case domain, email }

  private func presentInputAlert(title: String,
                                 message: String,
                                 placeholder: String,
                                 kind: InputKind) {

    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addTextField { textfield in
      textfield.placeholder = placeholder
      textfield.autocapitalizationType = .none
      textfield.autocorrectionType = .no
      textfield.keyboardType = (kind == .email) ? .emailAddress : .URL
      textfield.clearButtonMode = .whileEditing
    }

    let save = UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
      guard
        let self = self,
        let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
        self.isValid(text, for: kind)
      else { return }

      if kind == .domain {
        self.getAttentiveSdk().update(domain: text)
      }
      if kind == .email {
        self.getAttentiveSdk().identify([
          ATTNIdentifierType.email: text
        ])
      }

      self.showToast(with: "\(kind) updated")
    }
    save.isEnabled = false

    let cancel = UIAlertAction(title: "Cancel", style: .cancel)

    alert.addAction(cancel)
    alert.addAction(save)

    // Live validation to disable/enable Save
    if let tf = alert.textFields?.first {
      NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: tf, queue: .main) { [weak self, weak alert] _ in
        guard let self = self,
              let text = tf.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        let ok = self.isValid(text, for: kind)
        save.isEnabled = ok
        // Optional: visual hint by changing message
        alert?.message = ok ? message : self.validationMessage(for: kind)
      }
    }

    present(alert, animated: true)
  }

  private func isValid(_ value: String, for kind: InputKind) -> Bool {
    // 1) not super long
    let maxLen = 128
    guard !value.isEmpty, value.count <= maxLen else { return false }
    switch kind {
    case .domain:
        // Allow only alphanumeric
        let pattern = #"^[A-Za-z0-9]+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    case .email:
      let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
      return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
  }

  private func validationMessage(for kind: InputKind) -> String {
    switch kind {
    case .domain:
      return "Enter a valid domain (max 128 chars)"
    case .email:
      return "Enter a valid email like name@example.com (max 128 chars)."
    }
  }

  @objc private func sendLocalPushNotificationTapped() {
    showToast(with: "Push shows up in 5 seconds. Minimize app now.")
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

    let content = UNMutableNotificationContent()
    content.title = "🔔"
    content.body  = "Local push notification test"
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

    let req = UNNotificationRequest(identifier: "local_test", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(req) { error in
      if let err = error {
        print("Scheduling error:", err)
      }
    }
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
    guard let token = UserDefaults.standard.string(forKey: "attentiveDeviceToken"),
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
    let savedDeviceToken = UserDefaults.standard.string(forKey: "attentiveDeviceToken") ?? "Not saved"
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
