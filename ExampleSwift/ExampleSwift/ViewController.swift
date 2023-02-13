//
//  ViewController.swift
//  ExampleSwift
//
//  Created by Wyatt Davis on 2/9/23.
//

import Foundation
import os

class ViewController : UIViewController {
    @IBOutlet var creativeBtn : UIButton?
    @IBOutlet var sendIdentifiersBtn : UIButton?
    @IBOutlet var clearUserBtn : UIButton?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemGray3
    }
    
    @IBAction func creativeBtnPressed(sender: Any) {
        // Clear cookies to avoid Creative filtering during testing. Do not clear
        // cookies if you want to test Creative fatigue and filtering.
        self.clearCookies()
        
        // Display the creative.
        self.getAttentiveSdk().trigger(self.view)
    }

    @IBAction func sendIdentifiersBtnPressed(sender: Any) {
        self.getAttentiveSdk().identify(AppDelegate.createUserIdentifiers())
    }
    
    @IBAction func clearUserBtnPressed(sender: Any) {
        os_log("Clearing user!")
        self.getAttentiveSdk().clearUser()
    }
    
    private func clearCookies() {
        os_log("Clearing cookies!")
        
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeCookies], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {() -> Void in os_log("Cleared cookies!") })
    }
    
    private func getAttentiveSdk() -> ATTNSDK {
        return (UIApplication.shared.delegate as! AppDelegate).attentiveSdk!
    }
}
