//
//  AppDelegate.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/4/25.
//

import UIKit
import ATTNSDKFramework
import os
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  public var attentiveSdk : ATTNSDK?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    initializeAttentiveSdk()
    UNUserNotificationCenter.current().delegate = self
    // Show push permission prompt
    attentiveSdk?.registerForPushNotifications()
    return true
  }

  private func initializeAttentiveSdk() {
    // Intialize the Attentive SDK. Replace with your Attentive domain to test
    // with your Attentive account.
    // This only has to be done once per application lifecycle
    let sdk = ATTNSDK(domain: "YOUR_ATTENTIVE_DOMAIN", mode: .production)
    attentiveSdk = sdk

    // Initialize the ATTNEventTracker. This must be done before the ATTNEventTracker can be used to send any events. It only has to be done once per applicaiton lifecycle.
    ATTNEventTracker.setup(with: sdk)

    // Register the current user with the Attentive SDK by calling the `identify` method. Each identifier is optional, but the more identifiers you provide the better the Attentive SDK will function.
    // Every time any identifiers are added/changed, call the SDK's "identify" method
    sdk.identify(AppDelegate.createUserIdentifiers())
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      guard let self = self else { return }
      let authStatus = settings.authorizationStatus
      attentiveSdk?.registerDeviceToken(deviceToken, authorizationStatus: authStatus, callback: { data, url, response, error in
        DispatchQueue.main.async {
          self.attentiveSdk?.handleRegularOpen(authorizationStatus: authStatus)
        }
      })
    }

    // Please disregard below. These are for internal debugging purposes only.
    // Store device token as string for display on settings screen.
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

    UserDefaults.standard.set(tokenString, forKey: "deviceTokenForDisplay")
    NotificationCenter.default.post(name: NSNotification.Name("DeviceTokenUpdated"), object: nil)

    //store deviceToken as data type for sample app testing on settings screen that needs a data type to manually send push tokens
    UserDefaults.standard.set(deviceToken, forKey: "deviceTokenData")
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
    attentiveSdk?.failedToRegisterForPush(error)
  }

  public static func createUserIdentifiers() -> [String: Any] {
    [
      ATTNIdentifierType.phone: "+15671230987",
      ATTNIdentifierType.email: "someemail@email.com",
      ATTNIdentifierType.clientUserId: "APP_USER_ID",
      ATTNIdentifierType.shopifyId: "207119551",
      ATTNIdentifierType.klaviyoId: "555555",
      ATTNIdentifierType.customIdentifiers: ["customId": "customIdValue"]
    ]
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let presentationOptions: UNNotificationPresentationOptions = [.alert, .sound, .badge]
    completionHandler(presentationOptions)
  }
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let authStatus = settings.authorizationStatus
      DispatchQueue.main.async {
        switch UIApplication.shared.applicationState {
        case .active:
          self.attentiveSdk?.handleForegroundPush(response: response, authorizationStatus: authStatus)

        case .background, .inactive:
          self.attentiveSdk?.handlePushOpen(response: response, authorizationStatus: authStatus)

        @unknown default:
          self.attentiveSdk?.handlePushOpen(response: response, authorizationStatus: authStatus)
        }
      }
    }
    completionHandler()
  }
}

