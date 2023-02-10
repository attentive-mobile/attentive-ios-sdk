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
    
    
    var attentiveSdk : ATTNSDK?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemGray3
        
        self.attentiveSdk = (UIApplication.shared.delegate as! AppDelegate).attentiveSdk
    }
    
    @IBAction func creativeBtnPressed(sender: Any) {
        self.clearCookies()
        
        self.attentiveSdk!.trigger(self.view)
    }

    @IBAction func sendIdentifiersBtnPressed(sender: Any) {
        self.attentiveSdk!.identify(AppDelegate.createUserIdentifiers())
    }
    
    @IBAction func clearUserBtnPressed(sender: Any) {
        self.attentiveSdk!.clearUser()
    }
    
    private func clearCookies() {
        os_log("Clearing cookies!")
        
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeCookies], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {() -> Void in os_log("Cleared cookies!") })
    }
}
