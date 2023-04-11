//
//  AppInfo.h
//  attentive-ios-sdk-framework
//
//  Created by Wyatt Davis on 3/14/23.
//

#ifndef AppInfo_h
#define AppInfo_h

NS_ASSUME_NONNULL_BEGIN

@interface ATTNAppInfo : NSObject 

+ (NSString*) getAppBuild;
+ (NSString*) getAppVersion;
+ (NSString*) getAppName;
+ (NSString*) getAppId;

+ (NSString*) getDeviceModelName;
+ (NSString*) getDevicePlatform;
+ (NSString*) getDeviceOsVersion;

+ (NSString*) getSdkName;
+ (NSString*) getSdkVersion;

@end

NS_ASSUME_NONNULL_END

#endif /* AppInfo_h */
