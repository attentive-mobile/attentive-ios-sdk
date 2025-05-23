//
//  CreativeUITest.swift
//  CreativeUITest
//
//  Created by Vladimir - Work on 2024-06-05.
//

import XCTest
import WebKit

final class CreativeUITest: XCTestCase, BaseXCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    throw XCTSkip("Skipping all tests in CreativeUITest for now until we get new UI testing strategies implemented for new sample app")
  }

  override func tearDown() {
    clearCookies()
    resetUserDefaults()

    app.activate()

    super.tearDown()
  }

  func testLoadCreative_clickClose_closesCreative() {
    launch(with: .production, extras: [
      "SKIP_FATIGUE_ON_CREATIVE": "true"
    ])

    HomePage
      .tapOnPushMeToCreative()
      .addDelay(seconds: 5)

    CreativePage
      .tapOnCloseCreative()
      .addDelay()

    HomePage.verifyPushMeToCreativeIsHittable()
  }

  func testLoadCreative_fillOutFormAndSubmit_launchesSmsAppWithPrePopulatedText() {
    launch(with: .production)

    HomePage
      .tapOnClearUser()
      .tapOnPushMeToCreative()

    CreativePage
      .fillEmailInput(text: "testemail@attentivemobile.com")
      .dismissKeyboard()
      .tapOnContinue()
      .tapOnSubscribe()
      .addDelay(seconds: 3)

    guard canLaunchExternalApps else { return }

    SMSPage
      .verifyPrefilledMessage(
        message: "Send this text to subscribe to recurring automated personalized marketing alerts (e.g. cart reminders) from Attentive Mobile Apps Test"
      )
  }

  func testLoadCreative_clickPrivacyLink_opensPrivacyPageInWebApp() {
    launch(with: .production)

    HomePage.tapOnPushMeToCreative()

    CreativePage
      .addDelay(seconds: 3)
      .tapOnPrivacyLink()

    guard canLaunchExternalApps else { return }

    PricacyPolicyPage
      .addDelay(seconds: 5)
      .verifyContent()
  }

  func testLoadCreative_inDebugMode_showsDebugMessage() {
    launch(with: .debug)

    HomePage.tapOnPushMeToCreative()

    CreativePage.verifyDebugPage()
  }

  func testLoadCreative_clickProductPage_closesCreative() {
    launch(with: .production)

    HomePage.tapOnPushMeToCreative()

    CreativePage.verifyPrivacyLinkExists()

    HomePage.navigateToProduct()

    ProductPage
      .tapOnAddToCart()
      .navigateToMain()

    HomePage.verifyPushMeToCreativeIsHittable()
  }

  func testLoadCreative_switchDomain_shouldDisplayNewCreative() {
    launch(with: .production)

    HomePage
      .verifyDomainTitle(text: "mobileapps")
      .tapOnSwitchDomain()

    SwitchDomainPage
      .verifyIfTitleExists()
      .fillDomainInput(text: "games")
      .tapOnOk()
      .addDelay(seconds: 1)

    HomePage
      .verifyDomainTitle(text: "games")
      .tapOnPushMeToCreative()
      .addDelay(seconds: 4)

    CreativePage
      .verifyIfElementExists(label: "AttentiveGames", elementType: .image)
      .tapOnCloseCreative()
  }
}

extension CreativeUITest {
  func clearCookies() {
    print("Clearing cookies!")
    let websiteDataTypes: Set<String> = [WKWebsiteDataTypeCookies]
    let dateFrom = Date(timeIntervalSince1970: .zero)

    WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: dateFrom) {
      print("Cleared cookies!")
    }
  }

  func resetUserDefaults() {
    // Reset user defaults for example app, not the test runner
    UserDefaults.standard.removePersistentDomain(forName: "com.attentive.Example")
  }
}

