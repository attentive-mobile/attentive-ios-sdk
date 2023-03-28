//
//  ATTNUserAgentBuilderTest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 3/14/23.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "ATTNUserAgentBuilder.h"
#import "ATTNAppInfo.h"

@interface ATTNUserAgentBuilderTest : XCTestCase

@end


@implementation ATTNUserAgentBuilderTest {
    id _appInfoMock;
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _appInfoMock = [OCMockObject mockForClass:[ATTNAppInfo class]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [_appInfoMock stopMocking];
}

- (void)testBuildUserAgent_appInfoReturnsAllValues_userAgentIsFormattedCorrectly {
    [self mockAppInfo];
    
    NSString* actualUserAgent = [ATTNUserAgentBuilder buildUserAgent];
    
    XCTAssertEqualObjects(@"appName-Value/appVersionValue.appBuildValue (deviceModelNameValue; devicePlatformValue deviceOsVersionValue) sdkNameValue/sdkVersionValue", actualUserAgent);
}

static const NSString* APP_BUILD = @"appBuildValue";
static const NSString* APP_VERSION = @"appVersionValue";
static const NSString* APP_NAME = @"appName Value";
static const NSString* APP_ID = @"appIdValue";
static const NSString* DEVICE_MODEL_NAME = @"deviceModelNameValue";
static const NSString* DEVICE_PLATFORM = @"devicePlatformValue";
static const NSString* DEVICE_OS_VERSION = @"deviceOsVersionValue";
static const NSString* SDK_NAME = @"sdkNameValue";
static const NSString* SDK_VERSION = @"sdkVersionValue";

- (void)mockAppInfo {
    [[[_appInfoMock stub] andReturn:APP_BUILD] getAppBuild];
    [[[_appInfoMock stub] andReturn:APP_VERSION] getAppVersion];
    [[[_appInfoMock stub] andReturn:APP_NAME] getAppName];
    [[[_appInfoMock stub] andReturn:APP_ID] getAppId];

    [[[_appInfoMock stub] andReturn:DEVICE_MODEL_NAME] getDeviceModelName];
    [[[_appInfoMock stub] andReturn:DEVICE_PLATFORM] getDevicePlatform];
    [[[_appInfoMock stub] andReturn:DEVICE_OS_VERSION] getDeviceOsVersion];

    [[[_appInfoMock stub] andReturn:SDK_NAME] getSdkName];
    [[[_appInfoMock stub] andReturn:SDK_VERSION] getSdkVersion];
}

@end
