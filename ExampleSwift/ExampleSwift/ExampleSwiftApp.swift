//
//  ExampleSwiftApp.swift
//  ExampleSwift
//
//  Created by Wyatt Davis on 1/29/23.
//

import SwiftUI


class AttentiveData: ObservableObject {
    @Published var sdk : ATTNSDK?
    @Published var userIdentifiers : [String:String]?
}

/*
struct ExampleSwiftApp: App {
    init() {
        // TODO
    }
    
    //@StateObject var attentiveData : AttentiveData
    
    /*
    init() {
        // Alternatively, this code can go in your AppDelegate's "didFinishLaunchingWithOptions" method
        let sdk = ATTNSDK(domain: "games", mode: "production")
        
        // Intialize the Attentive SDK. Replace with your Attentive domain to test
        // with your Attentive account.
        // This only has to be done once per application lifecycle
        
        // Initialize the ATTNEventTracker. This must be done before the ATTNEventTracker can be used to send any events. It only has to be done once per applicaiton lifecycle.
        ATTNEventTracker.setup(with: sdk)
        
        // Register the current user with the Attentive SDK by calling the `identify` method. Each identifier is optional, but the more identifiers you provide the better the Attentive SDK will function.
        let userIdentifiers = [IDENTIFIER_TYPE_PHONE: "+15671230987"]/*[IDENTIFIER_TYPE_PHONE: "+14156667777",
                              IDENTIFIER_TYPE_EMAIL: "someemail@email.com",
                              IDENTIFIER_TYPE_CLIENT_USER_ID: "APP_USER_ID",
                              IDENTIFIER_TYPE_SHOPIFY_ID: "207119551",
                              IDENTIFIER_TYPE_KLAVIYO_ID: "555555"]*/
        sdk.identify(userIdentifiers)
        
        // Setup the 
        let attentiveData = AttentiveData();
        attentiveData.sdk = sdk;
        attentiveData.userIdentifiers = userIdentifiers
        let dataWrapper = StateObject(wrappedValue: attentiveData)
        self._attentiveData = dataWrapper
    }
     */

    var body: some Scene {
        WindowGroup {
            ContentView2()
        }
    }
}
*/
