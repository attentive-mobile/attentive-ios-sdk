//
//  AppDelegate.swift
//  ExampleSwift
//
//  Created by Wyatt Davis on 2/9/23.
//

import Foundation

@main
class AppDelegate : UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    public var attentiveSdk : ATTNSDK?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        initializeAttentiveSdk()

        return true
    }
    
    private func initializeAttentiveSdk() {
        // Intialize the Attentive SDK. Replace with your Attentive domain to test
        // with your Attentive account.
        // This only has to be done once per application lifecycle
        let sdk = ATTNSDK(domain: "YOUR_ATTENTIVE_DOMAIN", mode: "production")
        attentiveSdk = sdk
        
        // Initialize the ATTNEventTracker. This must be done before the ATTNEventTracker can be used to send any events. It only has to be done once per applicaiton lifecycle.
        ATTNEventTracker.setup(with: sdk)
        
        // Register the current user with the Attentive SDK by calling the `identify` method. Each identifier is optional, but the more identifiers you provide the better the Attentive SDK will function.
        // Every time any identifiers are added/changed, call the SDK's "identify" method
        sdk.identify(AppDelegate.createUserIdentifiers())
    }
    
    public static func createUserIdentifiers() -> [AnyHashable: Any] {
        return [IDENTIFIER_TYPE_PHONE: "+15671230987",
                  IDENTIFIER_TYPE_EMAIL: "someemail@email.com",
                  IDENTIFIER_TYPE_CLIENT_USER_ID: "APP_USER_ID",
                  IDENTIFIER_TYPE_SHOPIFY_ID: "207119551",
                  IDENTIFIER_TYPE_KLAVIYO_ID: "555555",
                  IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS: ["customId": "customIdValue"]]
    }
}
