//
//  IncludeAttentiveFramework.h
//  Example
//
//  Created by Wyatt Davis on 11/24/22.
//

// The point of this file is to conditionally load the SDK from either 1) the local Xcode project,
// or 2) the published attentive-ios-sdk pod.

// Use the framework from your local attentive-ios-sdk project
#if __has_include(<attentive_ios_sdk/ATTNSDK.h>)
#import <attentive_ios_sdk/ATTNSDKFramework.h>
#else
// Use the published pod version of the attentive-ios-sdk
// Since we build the pod into a static library, we should import all the needed public headers here (i.e. there is no umbrella header file)
#import "ATTNSDK.h"
#import "ATTNUserIdentity.h"
#import "ATTNEventTracker.h"
#import "ATTNPurchaseEvent.h"
#import "ATTNItem.h"
#import "ATTNPrice.h"
#import "ATTNOrder.h"
#import "ATTNCart.h"
// If for some reason we switched to building the pod into a dynamic framework, we can use this umbrella import instead:
// #import "attentive_ios_sdk/attentive-ios-sdk-umbrella.h"
#endif
