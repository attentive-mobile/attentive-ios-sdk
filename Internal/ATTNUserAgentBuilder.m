//
//  ATTNUserAgentBuilder.m
//  attentive-ios-sdk-framework
//
//  Created by Wyatt Davis on 3/14/23.
//

#import <Foundation/Foundation.h>
#import "ATTNUserAgentBuilder.h"
#import "ATTNAppInfo.h"

@implementation ATTNUserAgentBuilder

+ (NSString*)buildUserAgent {
    return [NSString stringWithFormat:@"%@/%@.%@ (%@; %@ %@) %@/%@",
            [self replaceSpacesWithDashes:[ATTNAppInfo getAppName]],
            [ATTNAppInfo getAppVersion],
            [ATTNAppInfo getAppBuild],
            [ATTNAppInfo getDeviceModelName],
            [ATTNAppInfo getDevicePlatform],
            [ATTNAppInfo getDeviceOsVersion],
            [ATTNAppInfo getSdkName],
            [ATTNAppInfo getSdkVersion]];
}

+ (NSString*)replaceSpacesWithDashes:(NSString*)stringToUpdate {
    return [stringToUpdate stringByReplacingOccurrencesOfString:@" " withString:@"-"];
}

@end
