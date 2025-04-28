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
    //registerForPushNotifications()
    attentiveSdk?.registerForPush()
    return true
  }

  private func initializeAttentiveSdk() {
      // Intialize the Attentive SDK. Replace with your Attentive domain to test
      // with your Attentive account.
      // This only has to be done once per application lifecycle
    let sdk = ATTNSDK(domain: "vs", mode: .production)
      attentiveSdk = sdk

      // Initialize the ATTNEventTracker. This must be done before the ATTNEventTracker can be used to send any events. It only has to be done once per applicaiton lifecycle.
      ATTNEventTracker.setup(with: sdk)

      // Register the current user with the Attentive SDK by calling the `identify` method. Each identifier is optional, but the more identifiers you provide the better the Attentive SDK will function.
      // Every time any identifiers are added/changed, call the SDK's "identify" method
      sdk.identify(AppDelegate.createUserIdentifiers())
  }

//  func registerForPushNotifications() {
//
////      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
////        print("register for push error: \(error?.localizedDescription)")
////          print("Permission granted: \(granted)")
////          guard granted else { return }
////          self.getNotificationSettings()
////      }
//  }
//
//  func getNotificationSettings() {
//      UNUserNotificationCenter.current().getNotificationSettings { settings in
//          print("Notification settings: \(settings)")
//          guard settings.authorizationStatus == .authorized else { return }
//          DispatchQueue.main.async {
//              UIApplication.shared.registerForRemoteNotifications()
//          }
//      }
//  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
//        let token = tokenParts.joined()
//        print("Device Token: \(token)")
//    UserDefaults.standard.set(token, forKey: "deviceToken")
//      UserDefaults.standard.synchronize()
    //TODO Find a way to save this and display in app
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
    print("Failed to register: \(error)")
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
        let userInfo = notification.request.content.userInfo
        // Handle the notification content here
        print("Foreground Notification received: \(userInfo)")
        completionHandler([.sound, .badge])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Handle the notification response here
        print("Background Notification received: \(userInfo)")
        completionHandler()
    }
}

