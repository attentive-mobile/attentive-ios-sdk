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

  // MARK: - New state
  private var currentEmail: String?
  private var currentPhone: String?

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
    button.setTitle("Switch User", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let switchDomainButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Switch domain", for: .normal)
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

  private let sendLocalPushNotification: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("🔔 Send \"Local\" Push Notification", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let sendCustomEventButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Send Custom Event (V2)", for: .normal)
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

  private let addEmailButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Add email", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let optInEmailButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Opt in email", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let optOutEmailButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Opt out email", for: .normal)
    button.setTitleColor(.systemRed, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let addPhoneButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Add phone", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let optInPhoneButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Opt in phone", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let optOutPhoneButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Opt out phone", for: .normal)
    button.setTitleColor(.systemRed, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private let currentEmailLabel: UILabel = {
    let label = UILabel()
    label.text = "Current email:"
    label.numberOfLines = 1
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let currentPhoneLabel: UILabel = {
    let label = UILabel()
    label.text = "Current phone:"
    label.numberOfLines = 1
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
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
    }

    setupUI()
    setupActions()
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
    stackView.addArrangedSubview(switchDomainButton)

    let divider = UIView()
    divider.backgroundColor = .lightGray
    divider.translatesAutoresizingMaskIntoConstraints = false
    divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
    stackView.addArrangedSubview(divider)

    stackView.addArrangedSubview(showCreativeButton)
    stackView.addArrangedSubview(showPushPermissionButton)
    stackView.addArrangedSubview(sendLocalPushNotification)
    stackView.addArrangedSubview(sendCustomEventButton)
    // TODO: Add back stackView.addArrangedSubview(identifyUserButton)
    stackView.addArrangedSubview(clearUserButton)
    stackView.addArrangedSubview(clearCookiesButton)
    stackView.addArrangedSubview(devicetokenLabel)
    stackView.addArrangedSubview(copyDeviceTokenButton)

    if let degular = UIFont(name: "DegularDisplay-Regular", size: 16) {
      let allButtons: [UIButton] = [
        switchAccountButton,
        switchDomainButton,
        showCreativeButton,
        showPushPermissionButton,
        sendLocalPushNotification,
        sendCustomEventButton,
        identifyUserButton,
        clearUserButton,
        clearCookiesButton,
        copyDeviceTokenButton
      ]
      allButtons.forEach {
        $0.titleLabel?.font = degular
        $0.titleLabel?.tintColor = .black
      }
      currentEmailLabel.font = degular
      currentPhoneLabel.font = degular
    }

    let emailRow = UIStackView(arrangedSubviews: [addEmailButton, optInEmailButton, optOutEmailButton])
    emailRow.axis = .horizontal
    emailRow.spacing = 12
    emailRow.distribution = .fillEqually

    let phoneRow = UIStackView(arrangedSubviews: [addPhoneButton, optInPhoneButton, optOutPhoneButton])
    phoneRow.axis = .horizontal
    phoneRow.spacing = 12
    phoneRow.distribution = .fillEqually

    stackView.addArrangedSubview(emailRow)
    stackView.addArrangedSubview(phoneRow)
    stackView.addArrangedSubview(currentEmailLabel)
    stackView.addArrangedSubview(currentPhoneLabel)

    // optional: match font to other buttons
    if let degular = UIFont(name: "DegularDisplay-Regular", size: 16) {
      [addEmailButton, optInEmailButton, optOutEmailButton,
       addPhoneButton, optInPhoneButton, optOutPhoneButton].forEach {
        $0.titleLabel?.font = degular
        $0.titleLabel?.tintColor = .black
      }
    }
  }

  // MARK: - Actions Setup

  private func setupActions() {
    switchAccountButton.addTarget(self, action: #selector(switchAccountTapped), for: .touchUpInside)
    switchDomainButton.addTarget(self, action: #selector(switchDomainTapped), for: .touchUpInside)
    showCreativeButton.addTarget(self, action: #selector(showCreativeTapped), for: .touchUpInside)
    showPushPermissionButton.addTarget(self, action: #selector(showPushPermissionTapped), for: .touchUpInside)
    sendLocalPushNotification.addTarget(self, action: #selector(sendLocalPushNotificationTapped), for: .touchUpInside)
    sendCustomEventButton.addTarget(self, action: #selector(sendCustomEventTapped), for: .touchUpInside)
    identifyUserButton.addTarget(self, action: #selector(identifyUserTapped), for: .touchUpInside)
    clearUserButton.addTarget(self, action: #selector(clearUserTapped), for: .touchUpInside)
    clearCookiesButton.addTarget(self, action: #selector(clearCookiesTapped), for: .touchUpInside)

    addEmailButton.addTarget(self, action: #selector(addEmailTapped), for: .touchUpInside)
    optInEmailButton.addTarget(self, action: #selector(optInEmailTapped), for: .touchUpInside)
    optOutEmailButton.addTarget(self, action: #selector(optOutEmailTapped), for: .touchUpInside)

    addPhoneButton.addTarget(self, action: #selector(addPhoneTapped), for: .touchUpInside)
    optInPhoneButton.addTarget(self, action: #selector(optInPhoneTapped), for: .touchUpInside)
    optOutPhoneButton.addTarget(self, action: #selector(optOutPhoneTapped), for: .touchUpInside)
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
    let alert = UIAlertController(title: "Update User", message: nil, preferredStyle: .alert)

    alert.addTextField { textfield in
      textfield.placeholder = "name@example.com"
      textfield.keyboardType = .emailAddress
      textfield.autocapitalizationType = .none
    }

    // Phone field needs E.164 format
    alert.addTextField { tf in
      tf.placeholder = "+15551234567"
      tf.keyboardType = .phonePad
    }

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
      let email = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
      let phone = alert.textFields?.last?.text?.trimmingCharacters(in: .whitespacesAndNewlines)

      self.currentEmail = (email?.isEmpty == false) ? email : nil
      self.currentPhone = (phone?.isEmpty == false) ? phone : nil

      self.currentEmailLabel.text = "Current email: \(self.currentEmail ?? "")"
      self.currentPhoneLabel.text = "Current phone: \(self.currentPhone ?? "")"

      self.getAttentiveSdk().clearUser()
      self.getAttentiveSdk().updateUser(
        email: self.currentEmail,
        phone: self.currentPhone
      ) { _, _, response, error in
        DispatchQueue.main.async {
          let status = (response as? HTTPURLResponse)?.statusCode ?? 0
          self.showToast(with: error == nil && status < 400
                         ? "User update successful"
                         : "User update failed")
        }
      }
    })

    present(alert, animated: true)
  }

  @objc private func switchDomainTapped() {
    let alert = UIAlertController(title: "Switch Domain",
                                  message: "Enter the new domain",
                                  preferredStyle: .alert)

    alert.addTextField { textfield in
      textfield.autocapitalizationType = .none
      textfield.autocorrectionType = .no
      textfield.keyboardType = .default
    }

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
      let raw = alert.textFields?.first?.text ?? ""
      let newDomain = raw.trimmingCharacters(in: .whitespacesAndNewlines)

      guard newDomain.isEmpty == false else {
        self.showToast(with: "Please enter a valid domain")
        return
      }

      let sdk = self.getAttentiveSdk()
      sdk.update(domain: newDomain)
      self.showToast(with: "Domain updated to “\(newDomain)”")
    })

    present(alert, animated: true)
  }

  @objc private func showCreativeTapped() {
    self.getAttentiveSdk().trigger(self.view)
  }

  @objc private func showPushPermissionTapped() {
    self.getAttentiveSdk().registerForPushNotifications()
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

  @objc private func sendCustomEventTapped() {
    guard let tracker = ATTNEventTracker.sharedInstance() else {
      print("Error: ATTNEventTracker not initialized")
      showToast(with: "Error: ATTNEventTracker not initialized")
      return
    }

    let customProperties: [String: String] = [
      "test_key_1": "test_value_1",
      "test_key_2": "test_value_2",
      "event_source": "settings_screen"
    ]
    tracker.recordEvent(.customEvent(customProperties: customProperties))
    showToast(with: "Custom Event sent!")
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

  @objc private func addEmailTapped() {
    let alert = UIAlertController(title: "Add Email", message: nil, preferredStyle: .alert)
    alert.addTextField { $0.placeholder = "name@example.com"; $0.keyboardType = .emailAddress }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
      let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
      self.currentEmail = (text?.isEmpty == false) ? text : nil
      self.currentEmailLabel.text = "Current email: \(self.currentEmail ?? "")"
      self.getAttentiveSdk().identify([ATTNIdentifierType.email : self.currentEmail ?? ""])
    })
    present(alert, animated: true)
  }

  @objc private func addPhoneTapped() {
    let alert = UIAlertController(title: "Add Phone", message: nil, preferredStyle: .alert)
    alert.addTextField { tf in
      tf.placeholder = "+15551234567"
      tf.keyboardType = .phonePad
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
      let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
      self.currentPhone = (text?.isEmpty == false) ? text : nil
      self.currentPhoneLabel.text = "Current phone: \(self.currentPhone ?? "")"
      self.getAttentiveSdk().identify([ATTNIdentifierType.phone : self.currentPhone ?? ""])
    })
    present(alert, animated: true)
  }

  @objc private func optInEmailTapped() {
    guard let email = currentEmail, !email.isEmpty else {
      showToast(with: "Add an email first"); return
    }
    getAttentiveSdk().optInMarketingSubscription(email: email) { _,_,response,error in
      _ = (response as? HTTPURLResponse)?.statusCode ?? 0
      DispatchQueue.main.async {
        self.showToast(with: error == nil ? "Email opt-in successful" : "Email opt-in failed")
      }
    }
  }

  @objc private func optOutEmailTapped() {
    guard let email = currentEmail, !email.isEmpty else {
      showToast(with: "Add an email first"); return
    }
    getAttentiveSdk().optOutMarketingSubscription(email: email) { _,_,response,error in
      _ = (response as? HTTPURLResponse)?.statusCode ?? 0
      DispatchQueue.main.async {
        self.showToast(with: error == nil ? "Email opt-out successful" : "Email opt-out failed")
      }
    }
  }

  @objc private func optInPhoneTapped() {
    guard let phone = currentPhone, !phone.isEmpty else {
      showToast(with: "Add a phone first"); return
    }
    getAttentiveSdk().optInMarketingSubscription(phone: phone) { _,_,response,error in
      _ = (response as? HTTPURLResponse)?.statusCode ?? 0
      DispatchQueue.main.async {
        self.showToast(with: error == nil ? "Phone opt-in successful" : "Phone opt-in failed")
      }
    }
  }

  @objc private func optOutPhoneTapped() {
    guard let phone = currentPhone, !phone.isEmpty else {
      showToast(with: "Add a phone first"); return
    }
    getAttentiveSdk().optOutMarketingSubscription(phone: phone) { _,_,response,error in
      _ = (response as? HTTPURLResponse)?.statusCode ?? 0
      DispatchQueue.main.async {
        self.showToast(with: error == nil ? "Phone opt-out successful" : "Phone opt-out failed")
      }
    }
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
