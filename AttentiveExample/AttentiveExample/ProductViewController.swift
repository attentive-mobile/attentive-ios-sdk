//
//  ProductViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/4/25.
//

import UIKit
import ATTNSDKFramework
import WebKit
import os.log

class ProductViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
  @IBAction func showCreativeButtonPressed(_ sender: Any) {
    self.clearCookies()
    do {
      let sdk = try self.getAttentiveSdk()
      sdk.trigger(self.view, creativeId: "1105292")
    } catch {
      os_log("Error triggering creative: %@", error.localizedDescription)
    }
  }

  private func clearCookies() {
      os_log("Clearing cookies!")

      WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeCookies], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {() -> Void in os_log("Cleared cookies!") })
  }

  private func getAttentiveSdk() throws -> ATTNSDK {
      guard let sdk = (UIApplication.shared.delegate as? AppDelegate)?.attentiveSdk else {
          throw AttentiveSDKError.sdkNotInitialized
      }
      return sdk
  }

}
