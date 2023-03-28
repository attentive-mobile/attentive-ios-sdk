//
//  AppInfo.m
//  attentive-ios-sdk-framework
//
//  Created by Wyatt Davis on 3/14/23.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "ATTNAppInfo.h"
#import "ATTNVersion.h"

@implementation ATTNAppInfo

+ (NSString*) getAppBuild {
    return [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
}
+ (NSString*) getAppVersion {
    return [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
}
+ (NSString*) getAppName {
    return [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
}
+ (NSString*) getAppId {
    return [[NSBundle mainBundle] bundleIdentifier];
}

+ (NSString*) getDeviceModelName {
    return [[UIDevice currentDevice] model];
}

+ (NSString*) getDevicePlatform {
    return [[UIDevice currentDevice] systemName];
}

+ (NSString*) getDeviceOsVersion {
    return [[NSProcessInfo processInfo] operatingSystemVersionString];
}

+ (NSString*) getSdkName {
    return @"attentive-ios-sdk";
}

+ (NSString*) getSdkVersion {
    return SDK_VERSION;
}

@end
