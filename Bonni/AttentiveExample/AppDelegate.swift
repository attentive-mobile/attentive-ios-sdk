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

    return true
  }

  private func initializeAttentiveSdk() {
    // Intialize the Attentive SDK. Replace with your Attentive domain to test
    // with your Attentive account.
    // This only has to be done once per application lifecycle
    ATTNSDK.initialize(domain: "games", mode: .production) { result in
      switch result {
      case .success(let sdk):
        self.attentiveSdk = sdk
        ATTNEventTracker.setup(with: sdk)

        // Register the current user with the Attentive SDK by calling the `identify` method. Each identifier is optional, but the more identifiers you provide the better the Attentive SDK will function.
        // Every time any identifiers are added/changed, call the SDK's "identify" method
        // sdk.identify(AppDelegate.createUserIdentifiers())
      case .failure(let error):
        // Handle init failure
        print("Attentive SDK failed to initialize: \(error)")
      }
    }
  }

//  Uncomment this if needed
//  public static func createUserIdentifiers() -> [String: Any] {
//    [
//      ATTNIdentifierType.phone: "+15671230987",
//      ATTNIdentifierType.email: "someemail@email.com",
//      ATTNIdentifierType.clientUserId: "APP_USER_ID",
//      ATTNIdentifierType.shopifyId: "207119551",
//      ATTNIdentifierType.klaviyoId: "555555",
//      ATTNIdentifierType.customIdentifiers: ["customId": "customIdValue"]
//    ]
//  }
}
