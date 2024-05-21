# Attentive IOS SDK

The Attentive IOS SDK provides the functionality to render Attentive creative units and collect Attentive events in IOS mobile applications.

## Installation

### Cocoapods

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

### Swift Package Manager

We also support adding the dependency via Swift Package Manager.

In your applications `Package.swift` file, add the attentive-ios-sdk as a dependency:

```
dependencies: [
    // your other app dependencies
    .package(url: "https://github.com/attentive-mobile/attentive-ios-sdk", from: "0.5.0"),
],
```

This will allow your package to update patch releases with `swift package update`, but won't auto-upgrade any minor or major versions.

Then, from a command line, run:

```
swift package resolve
```

To update your local package, run `swift package update`.

To check for new major and minor versions of this SDK, navigate to the [releases](https://github.com/attentive-mobile/attentive-ios-sdk/releases) tab of the project. You can then manually update the version in your `Package.swift` file and run `swift package resolve` to complete the update.

## Usage

See the [Example Project](https://github.com/attentive-mobile/attentive-ios-sdk/tree/main/Example) for a sample of how the Attentive
IOS SDK is used.

****_ NOTE: Please refrain from using any internal or undocumented classes or methods as they may change between releases. _****

### Initialize the SDK

The code snippets and examples below assume you are working in Objective C. To make the SDK available, you need to import the header
file after installing the SDK:

#### Objective-C

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

#### Swift

```swift
import attentive_ios_sdk
```

```swift
let sdk = ATTNSDK(domain: "myCompanyDomain")

let sdk = ATTNSDK(domain: "myCompanyDomain", mode: "debug")

ATTNEventTracker.setup(with: sdk)
```

### Identify information about the current user

Register any identifying information you have about the user with the Attentive SDK. This method can be called any time you have new information to attribute to the user.

#### Objective-C

```objectiveC
[sdk identify:@{ 
  IDENTIFIER_TYPE_CLIENT_USER_ID: @"myAppUserId", 
  IDENTIFIER_TYPE_PHONE: @"+15556667777"
}];
```

#### Swift

```swift
sdk.identify([
  IDENTIFIER_TYPE_CLIENT_USER_ID : "myAppUserId",
  IDENTIFIER_TYPE_PHONE : "+15556667777"
])
```
The more identifiers that are passed to `identify`, the better the SDK will function. Here is the list of possible identifiers:
| Identifier Name | Constant Name | Type | Description |
| ------------------ | ------------------ | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Client User ID | `IDENTIFIER_TYPE_CLIENT_USER_ID` | NSString * | Your unique identifier for the user. This should be consistent across the user's lifetime. For example, a database id. |
| Phone | `IDENTIFIER_TYPE_PHONE` | NSString* | The users's phone number in E.164 format |
| Email | `IDENTIFIER_TYPE_EMAIL` | NSString* | The users's email |
| Shopify ID | `IDENTIFIER_TYPE_SHOPIFY_ID` | NSString* | The users's Shopify ID |
| Klaviyo ID | `IDENTIFIER_TYPE_KLAVIYO_ID` | NSString* | The users's Klaviyo ID |
| Custom Identifiers | `IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS` | NSDictionary<NSString *, NSString _>_ | Key-value pairs of custom identifier names and values. The values should be unique to this user. |

For each identifier type, use the name `IDENTIFIER_TYPE_{IDENTIFIER_NAME}` for the key name in the user identifiers map.

### Load and render the creative

#### Objective-C

```objectiveC
// Load the creative with a completion handler.
[sdk trigger:self.view
     handler:^(NSString *triggerStatus) {
      // Status passed to ATTNCreativeTriggerCompletionHandler when the creative is opened sucessfully
      if (triggerStatus == CREATIVE_TRIGGER_STATUS_OPENED) {
        NSLog(@"Opened the Creative!");
      }
      // Status passed to the ATTNCreativeTriggerCompletionHandler when the Creative has been triggered but it is not opened successfully. 
      // This can happen if there is no available mobile app creative, if the creative is fatigued, if the creative call has been timed out, or if an unknown exception occurs.
      else if (triggerStatus == CREATIVE_TRIGGER_STATUS_NOT_OPENED) {
        NSLog(@"Couldn't open the Creative!");
      }
      // Status passed to ATTNCreativeTriggerCompletionHandler when the creative is closed sucessfully
      else if (triggerStatus == CREATIVE_TRIGGER_STATUS_CLOSED) {
        NSLog(@"Closed the Creative!");
      }
      // Status passed to the ATTNCreativeTriggerCompletionHandler when the Creative is not closed due to an unknown exception
      else if (triggerStatus == CREATIVE_TRIGGER_STATUS_NOT_CLOSED) {
        NSLog(@"Couldn't close the Creative!");
      }
      }];
```

#### Swift

```swift
sdk.trigger(view) { status in
  switch status {
  case CREATIVE_TRIGGER_STATUS_OPENED:
    print("Opened the Creative!")
  case CREATIVE_TRIGGER_STATUS_NOT_OPENED:
    print("Couldn't open the Creative!")
  case CREATIVE_TRIGGER_STATUS_CLOSED:
    print("Closed the Creative!")
  case CREATIVE_TRIGGER_STATUS_NOT_CLOSED:
    print("Couldn't close the Creative!")
  default:
    break
  }
}
```

#### Objective-C

```objectiveC
// Alternatively, you can load the creative without a completion handler
[sdk trigger:self.view];
```

#### Swift

```swift
sdk.trigger(view)
```

### Record user events

The SDK currently supports `ATTNPurchaseEvent`, `ATTNAddToCartEvent`, `ATTNProductViewEvent`, and `ATTNCustomEvent`.

#### Objective-C

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

#### Swift

```swift
let price = ATTNPrice(price: NSDecimalNumber(string: "15.99"), currency: "USD")

let item = ATTNItem(productId: "222", productVariantId: "55555", price: price)

let order = ATTNOrder(orderId: "778899")

let purchase = ATTNPurchaseEvent(items: [item], order: order)

ATTNEventTracker.sharedInstance().record(purchase)
```

### Clear the current user

If the user logs out then the current user identifiers should be deleted:

#### Objective-C

```objectiveC
[sdk clearUser];
```

#### Swift

```swift
sdk.clearUser()
```

When/if the user logs back in, `identify` should be called again with the user's identfiers
