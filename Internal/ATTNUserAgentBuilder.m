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
    // We replace the spaces with dashes for the app name because spaces in a User-Agent represent a new "product", so app names that have spaces are harder to parse if we don't replace spaces with dashes
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
