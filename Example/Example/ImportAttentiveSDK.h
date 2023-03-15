//
//  IncludeAttentiveFramework.h
//  Example
//
//  Created by Wyatt Davis on 11/24/22.
//

// The point of this file is to conditionally load the SDK from either 1) the local Xcode project,
// or 2) the published attentive-ios-sdk pod.

// Use the framework from your local attentive-ios-sdk project
#if __has_include(<attentive_ios_sdk_framework/ATTNSDK.h>)
#import <attentive_ios_sdk_framework/ATTNSDKFramework.h>
#else
// Load the headers from the attentive-ios-sdk Pod
#import "attentive_ios_sdk/attentive-ios-sdk-umbrella.h"
#endif
