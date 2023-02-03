//
//  AppDelegate.swift
//  ExampleSwift - Local
//
//  Created by Wyatt Davis on 1/30/23.
//

import Foundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    var sdk : ATTNSDK?
    var userIdentifiers : [String:String]?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        /*
        // Intialize the Attentive SDK. Replace with your Attentive domain to test
        // with your Attentive account.
        // This only has to be done once per application lifecycle
        sdk = ATTNSDK(domain: "games", mode: "production")
        
        // Initialize the ATTNEventTracker. This must be done before the ATTNEventTracker can be used to send any events. It only has to be done once per applicaiton lifecycle.
        ATTNEventTracker.setup(with: sdk!)
        
        // Register the current user with the Attentive SDK by calling the `identify` method. Each identifier is optional, but the more identifiers you provide the better the Attentive SDK will function.
        userIdentifiers = [IDENTIFIER_TYPE_PHONE: "+14156667777",
                              IDENTIFIER_TYPE_EMAIL: "someemail@email.com",
                              IDENTIFIER_TYPE_CLIENT_USER_ID: "APP_USER_ID",
                              IDENTIFIER_TYPE_SHOPIFY_ID: "207119551",
                              IDENTIFIER_TYPE_KLAVIYO_ID: "555555"]
        sdk!.identify(userIdentifiers!)
*/
        return true
    }
}
