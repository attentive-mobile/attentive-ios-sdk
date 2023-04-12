# Attentive IOS SDK

The Attentive IOS SDK provides the functionality to render Attentive creative units and collect Attentive events in IOS mobile applications.


## Installation

The attentive-ios-sdk is available through [CocoaPods](https://cocoapods.org). To install the SDK in a separate project using Cocoapods, include the pod in your application’s Podfile:

```
target 'MyApp' do
  pod 'attentive-ios-sdk', 'THE_SDK_VERSION'
end
```

And then make sure to run:

```
pod install
```

Check for new versions of the SDK using this command:
```
pod update attentive-ios-sdk
```
You can then update the version in your pod file and run `pod install` again to pull the changes.

## Usage
See the [Example Project](https://github.com/attentive-mobile/attentive-ios-sdk/tree/main/Example) for a sample of how the Attentive
IOS SDK is used.

__*** NOTE: Please refrain from using any internal or undocumented classes or methods as they may change between releases. ***__


### Initialize the SDK

The code snippets and examples below assume you are working in Objective C. To make the SDK available, you need to import the header
file after installing the SDK:
```objectiveC
#import "attentive_ios_sdk/attentive-ios-sdk-umbrella.h"
```

```objectiveC
// Initialize the SDK with your attentive domain, in production mode
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"myCompanyDomain"];

// Alternatively, initialize the SDK in debug mode for more information about your creative and filtering rules
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"myCompanyDomain" mode:@"debug"];

// Initialize the AttentiveEventTracker. The AttentiveEventTracker is used to send user events (e.g. a Purchase) to Attentive. It must be set up before it can be used to send events.
[ATTNEventTracker setupWithSDk:sdk];
```

### Identify information about the current user

Register any identifying information you have about the user with the Attentive SDK. This method can be called any time you have new information to attribute to the user.

```objectiveC
[sdk identify:@{ IDENTIFIER_TYPE_CLIENT_USER_ID: @"myAppUserId", IDENTIFIER_TYPE_PHONE: @"+15556667777"}];
```

The more identifiers that are passed to `identify`, the better the SDK will function. Here is the list of possible identifiers:
| Identifier Name    | Type                                  | Description                                                                                                             |
| ------------------ | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Client User ID     | NSString*                             | Your unique identifier for the user. This should be consistent across the user's lifetime. For example, a database id.  |
| Phone              | NSString*                             | The users's phone number in E.164 format                                                                                |
| Email              | NSString*                             | The users's email                                                                                                       |
| Shopify ID         | NSString*                             | The users's Shopify ID                                                                                                  |
| Klaviyo ID         | NSString*                             | The users's Klaviyo ID                                                                                                  | 
| Custom Identifiers | NSDictionary<NSString *, NSString *>* | Key-value pairs of custom identifier names and values. The values should be unique to this user.                        |

For each identifier type, use the name `IDENTIFIER_TYPE_{IDENTIFIER_NAME}` for the key name in the user identifiers map.

### Load and render the creative

```objectiveC
[sdk trigger:self.view];
```

### Record user events

The SDK currently supports `ATTNPurchaseEvent`, `ATTNAddToCartEvent`, `ATTNProductViewEvent`, and `ATTNCustomEvent`.

```objectiveC
// Create the Item(s) that was/were purchased
ATTNItem* item = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];
// Create the Order
ATTNOrder* order = [[ATTNOrder alloc] initWithOrderId:@"778899"];
// Create PurchaseEvent
ATTNPurchaseEvent* purchase = [[ATTNPurchaseEvent alloc] initWithItems:@[item] order:order];

// Finally, record the event!
[[ATTNEventTracker sharedInstance] recordEvent:purchase];
```

### Clear the current user

If the user logs out then the current user identifiers should be deleted:

```objectiveC
[sdk clearUser];
```

When/if the user logs back in, `identify` should be called again with the user's identfiers
