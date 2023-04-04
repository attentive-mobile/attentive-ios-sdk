//
//  CreativeUITest.m
//  CreativeUITest
//
//  Created by Olivia Kim on 2/14/23.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@interface CreativeUITest : XCTestCase

@end


@implementation CreativeUITest {
    XCUIApplication *app;
}


- (void)setUp {
    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;
    
    [[self class] clearCookies];
    
    app = [[XCUIApplication alloc] init];
}

+ (void)tearDown {
    // reset cookies & user defaults after all tests have run
    [self clearCookies];
    [self resetUserDefaults];
}


- (void)testLoadCreative_clickClose_closesCreative {
    [self launchAppWithMode:@"production"];
    [app.buttons[@"Push me for Creative!"] tap];
    
    // Close the creative
    XCTAssertTrue([app.webViews.buttons[@"close"] waitForExistenceWithTimeout:5.0]);
    [app.webViews.buttons[@"close"] tap];
    
    // Assert that the creative is closed
    XCTAssertTrue([app.buttons[@"Push me for Creative!"] waitForExistenceWithTimeout:5.0]);
    XCTAssertEqual(app.buttons[@"Push me for Creative!"].isHittable, true);
}


- (void)testLoadCreative_fillOutFormAndSubmit_launchesSmsAppWithPrePopulatedText {
    [self launchAppWithMode:@"production"];
    [app.buttons[@"Push me for Creative!"] tap];

    // Fill in the email
    XCTAssertTrue([app.webViews.textFields[@"Email Address"] waitForExistenceWithTimeout:5.0]);
    XCUIElement *emailField = app.webViews.textFields[@"Email Address"];
    [emailField tap];
    [emailField typeText:@"testemail@attentivemobile.com"];
    
    // Tap something else on the creative to dismiss the keyboard
    [app.staticTexts[@"10% OFF"] tap];
    
    // Submit email
    XCTAssertTrue([app.buttons[@"CONTINUE"] waitForExistenceWithTimeout:5.0]);
    [app.webViews.buttons[@"CONTINUE"] tap];
    
    // Click subscribe button
    XCTAssertTrue([app.buttons[@"GET 10% OFF NOW when you sign up for email and texts"] waitForExistenceWithTimeout:5.0]);
    [app.buttons[@"GET 10% OFF NOW when you sign up for email and texts"] tap];

    // Assert that the SMS app is opened with prepopulated text if running locally
    // (AWS Device Farm doesn't allow use of SMS apps)
    NSString * envHost = [[[NSProcessInfo processInfo] environment] objectForKey:@"COM_ATTENTIVE_EXAMPLE_HOST"];
    if ([envHost isEqualToString:@"local"]) {
        XCUIApplication * smsApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.MobileSMS"];
        XCTAssertTrue([smsApp.textFields[@"Message"] waitForExistenceWithTimeout:5.0]);
        XCTAssertTrue([smsApp.textFields[@"Message"].value containsString:@"Send this text to subscribe to recurring automated personalized marketing alerts (e.g. cart reminders) from Attentive Mobile Apps Test"]);
    }
}


- (void)testLoadCreative_clickPrivacyLink_opensPrivacyPageInWebApp {
    [self launchAppWithMode:@"production"];
    [app.buttons[@"Push me for Creative!"] tap];

    // Click privacy link
    XCTAssertTrue([app.webViews.links[@"Privacy"] waitForExistenceWithTimeout:5.0]);
    [app.webViews.links[@"Privacy"] tap];

    // Verify that the privacy page is visible in the external browser
    XCUIApplication * safariApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.mobilesafari"];
    XCTAssertTrue([safariApp.staticTexts[@"Privacy Policy"] waitForExistenceWithTimeout:5.0]);
}


- (void)testLoadCreative_inDebugMode_showsDebugMessage {
    [self launchAppWithMode:@"debug"];
    [app.buttons[@"Push me for Creative!"] tap];

    // Verify debug page shows
    XCTAssertTrue([app.staticTexts[@"Debug output JSON:"] waitForExistenceWithTimeout:5.0]);
}


+ (void)clearCookies {
    NSLog(@"Clearing cookies!");
    NSSet *websiteDataTypes = [NSSet setWithArray:@[WKWebsiteDataTypeCookies]];
    NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                               modifiedSince:dateFrom
                                           completionHandler:^() {
        NSLog(@"Cleared cookies!");
    }];
}


+ (void)resetUserDefaults {
    // Reset user defaults for example app, not the test runner
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:@"com.attentive.Example"];
}


- (void)launchAppWithMode:(NSString *) mode {
    app.launchEnvironment = @{
        @"COM_ATTENTIVE_EXAMPLE_DOMAIN": @"mobileapps",
        @"COM_ATTENTIVE_EXAMPLE_MODE": mode,
        @"COM_ATTENTIVE_EXAMPLE_IS_UI_TEST": @"YES",
    };
    [app launch];
}


@end
