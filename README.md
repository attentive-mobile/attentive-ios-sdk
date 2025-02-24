# Attentive IOS SDK

The Attentive IOS SDK provides the functionality to render Attentive creative units and collect Attentive events in IOS mobile applications.

## Installation

### Cocoapods

The attentive-ios-sdk is available through [CocoaPods](https://cocoapods.org). To install the SDK in a separate project using Cocoapods, include the pod in your application’s Podfile:

```ruby
target 'MyApp' do
  pod 'ATTNSDKFramework', '1.0.1'
end
```

And then make sure to run:

```ruby
pod install
```

Check for new versions of the SDK using this command:

```ruby
pod update ATTNSDKFramework
```

You can then update the version in your pod file and run `pod install` again to pull the changes.

> [!IMPORTANT]
> `attentive-ios-sdk` was deprecated in favor of `ATTNSDKFramework`. Please update your Podfile with the newest name for the SDK.

### Swift Package Manager

We also support adding the dependency via Swift Package Manager.

In your applications `Package.swift` file, add the attentive-ios-sdk as a dependency:

```swift
dependencies: [
    // your other app dependencies
    .package(url: "https://github.com/attentive-mobile/attentive-ios-sdk", from: "1.0.1"),
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

> [!IMPORTANT]
> Please refrain from using any internal or undocumented classes or methods as they may change between releases.

### Initialize the SDK

The code snippets and examples below assume you are working in Objective C. To make the SDK available, you need to import the header
file after installing the SDK:

#### Swift

```swift
import ATTNSDKFramework
```

```swift
// Initialize the SDK with your attentive domain, in production mode
let sdk = ATTNSDK(domain: "myCompanyDomain")

// Alternatively, initialize the SDK in debug mode for more information about your creative and filtering rules
let sdk = ATTNSDK(domain: "myCompanyDomain", mode: .debug)

// Initialize the AttentiveEventTracker. The AttentiveEventTracker is used to send user events (e.g. a Purchase) to Attentive. It must be set up before it can be used to send events.
ATTNEventTracker.setup(with: sdk)
```

#### Objective-C

```objective-c
#import "ATTNSDKFramework-Swift.h"
#import "ATTNSDKFramework-umbrella.h"
```

```objective-c

ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"myCompanyDomain"];

ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"myCompanyDomain" mode:@"debug"];

[ATTNEventTracker setupWithSDk:sdk];
```

### Identify information about the current user

Register any identifying information you have about the user with the Attentive SDK. This method can be called any time you have new information to attribute to the user.

#### Swift

```swift
sdk.identify([
  ATTNIdentifierType.clientUserId : "myAppUserId",
  ATTNIdentifierType.phone : "+15556667777"
])
```

#### Objective-C

```objective-c
[sdk identify:@{
  ATTNIdentifierType.clientUserId: @"myAppUserId",
  ATTNIdentifierType.phone: @"+15556667777"
}];
```

The more identifiers that are passed to `identify`, the better the SDK will function. Here is the list of possible identifiers available in `ATTNIdentifierType`:
| Identifier Name | Constant Name | Type | Description |
| ------------------ | ------------------ | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Client User ID | `clientUserId` | `String` | Your unique identifier for the user. This should be consistent across the user's lifetime. For example, a database id. |
| Phone | `phone` | `String` | The users's phone number in E.164 format |
| Email | `email` | `String` | The users's email |
| Shopify ID | `shopifyId` | `String` | The users's Shopify ID |
| Klaviyo ID | `klaviyoId` | `String` | The users's Klaviyo ID |
| Custom Identifiers | `customIdentifiers` | `[String: String]` | Key-value pairs of custom identifier names and values. The values should be unique to this user. |

### Load and render the creative

#### Swift

```swift
sdk.trigger(view) { status in
  switch status {
  // Status passed to ATTNCreativeTriggerCompletionHandler when the creative is opened sucessfully
  case ATTNCreativeTriggerStatus.opened:
    print("Opened the Creative!")
  // Status passed to the ATTNCreativeTriggerCompletionHandler when the Creative has been triggered but it is not opened successfully. 
  // This can happen if there is no available mobile app creative, if the creative is fatigued, if the creative call has been timed out, or if an unknown exception occurs.
  case ATTNCreativeTriggerStatus.notOpened:
    print("Couldn't open the Creative!")
  // Status passed to ATTNCreativeTriggerCompletionHandler when the creative is closed sucessfully
  case ATTNCreativeTriggerStatus.closed:
    print("Closed the Creative!")
  // Status passed to the ATTNCreativeTriggerCompletionHandler when the Creative is not closed due to an unknown exception
  case ATTNCreativeTriggerStatus.notClosed:
    print("Couldn't close the Creative!")
  default:
    break
  }
}
```

#### Objective-C

```objective-c
// Load the creative with a completion handler.
[sdk trigger:self.view
     handler:^(NSString *triggerStatus) {
      if (triggerStatus == ATTNCreativeTriggerStatus.opened) {
        NSLog(@"Opened the Creative!");
      } else if (triggerStatus == ATTNCreativeTriggerStatus.notOpened) {
        NSLog(@"Couldn't open the Creative!");
      } else if (triggerStatus == ATTNCreativeTriggerStatus.closed) {
        NSLog(@"Closed the Creative!");
      } else if (triggerStatus == ATTNCreativeTriggerStatus.notClosed) {
        NSLog(@"Couldn't close the Creative!");
      }
    }];
```
#### Swift

```swift
// Alternatively, you can load the creative without a completion handler
sdk.trigger(view)
```

#### Objective-C

```objective-c
[sdk trigger:self.view];
```

### Record user events

The SDK currently supports `ATTNPurchaseEvent`, `ATTNAddToCartEvent`, `ATTNProductViewEvent`, and `ATTNCustomEvent`.

#### Swift

```swift
let price = ATTNPrice(price: NSDecimalNumber(string: "15.99"), currency: "USD")

// Create the Item(s) that was/were purchased
let item = ATTNItem(productId: "222", productVariantId: "55555", price: price)

// Create the Order
let order = ATTNOrder(orderId: "778899")

// Create PurchaseEvent
let purchase = ATTNPurchaseEvent(items: [item], order: order)

// Finally, record the event!
ATTNEventTracker.sharedInstance().record(event: purchase)
```

#### Objective-C

```objective-c
ATTNItem* item = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];

ATTNOrder* order = [[ATTNOrder alloc] initWithOrderId:@"778899"];

ATTNPurchaseEvent* purchase = [[ATTNPurchaseEvent alloc] initWithItems:@[item] order:order];

[[ATTNEventTracker sharedInstance] recordEvent:purchase];
```
---
For `ATTNProductViewEvent` and `ATTNAddToCartEvent,` you can include a `deeplink` in the init method or the property to incentivize the user to complete a specific flow.

#### Swift

```swift
// Init method
let addToCart = ATTNAddToCartEvent(items: items, deeplink: "https://mydeeplink.com/products/32432423")
ATTNEventTracker.sharedInstance()?.record(event: addToCart)

// Property
let productView = ATTNProductViewEvent(items: items)
productView.deeplink = "https://mydeeplink.com/products/32432423"
ATTNEventTracker.sharedInstance()?.record(event: productView)
```

#### Objective-C
```objective-c
// Init Method
ATTNAddToCartEvent* addToCart = [[ATTNAddToCartEvent alloc] initWithItems:items deeplink:@"https://mydeeplink.com/products/32432423"];
  [[ATTNEventTracker sharedInstance] recordEvent:addToCart];

// Property
ATTNProductViewEvent* productView = [[ATTNProductViewEvent alloc] initWithItems:items];
productView.deeplink = @"https://mydeeplink.com/products/32432423";
[[ATTNEventTracker sharedInstance] recordEvent:productView];
```
---

The SDK allows custom events to be sent using `ATTNCustomEvent,` where type is the event name and the properties is a dictionary(`[String: String]`) with the information to populate dynamic content in the message to subscribers.

#### Swift

```swift
// ☝️ Init can return nil if there are issues with the provided data in properties
guard let customEvent = ATTNCustomEvent(type: "Concert Viewed", properties: ["band": "Myrath"]) else { return }
ATTNEventTracker.sharedInstance()?.record(event: customEvent)
```

#### Objective-C

```objective-c
ATTNCustomEvent* customEvent = [[ATTNCustomEvent alloc] initWithType:@"Concert Viewed" properties:@{@"band" : @"Myrath"}];
[[ATTNEventTracker sharedInstance] recordEvent:customEvent];
```

### Switch to another domain

Reinitialize the SDK with a different domain.

#### Swift

```swift
let sdk = ATTNSDK(domain: "domain")
sdk.update(domain: "differentDomain")
```

#### Objective-C

```objective-c
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"domain"];
[sdk updateDomain: @"differentDomain"];
```

### Skip Fatigue on Creative

Determinates if fatigue rules evaluation will be skipped for Creative. Default value is `false`.

#### Swift

```swift
let sdk = ATTNSDK(domain: "domain")
sdk.skipFatigueOnCreative = true
```

#### Objective-C

```objective-c
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"domain"];
sdk.skipFatigueOnCreative = YES;
```

Alternatively, `SKIP_FATIGUE_ON_CREATIVE` can be added as an environment value in the project scheme or even included in CI files.

Environment value can be a string with value `"true"` or `"false"`.

### Clear the current user

If the user logs out then the current user identifiers should be deleted:

#### Swift

```swift
sdk.clearUser()
```

#### Objective-C

```objective-c
[sdk clearUser];
```

When/if the user logs back in, `identify` should be called again with the user's identfiers

## Changelog

Click [here](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/CHANGELOG.md) for a complete change log of every released version
