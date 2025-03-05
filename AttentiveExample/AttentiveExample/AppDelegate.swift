//
//  AppDelegate.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/4/25.
//

import UIKit
import ATTNSDKFramework
import os

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  public var attentiveSdk : ATTNSDK?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    initializeAttentiveSdk()
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

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }


}

