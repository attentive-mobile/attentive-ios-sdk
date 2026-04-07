# Attentive iOS SDK

The Attentive mobile SDK provides functionalities like gathering user identity, collecting event data, and rendering creatives for your app. This enables cross-platform journeys, enhanced reporting, and revenue attributions.

## Prerequisites

### Cocoapods

The attentive-ios-sdk is available through [CocoaPods](https://cocoapods.org). To install the SDK in a separate project using Cocoapods, include the pod in your application’s Podfile:

```ruby
target 'MyApp' do
  pod 'attentive-ios-sdk', '2.0.13'
end
```

And then make sure to run:

```ruby
pod install
```


### Swift Package Manager (Recommended)

We also support adding the dependency via Swift Package Manager. SPM resolves a pre-built universal `XCFramework` from the GitHub release and automatically handles embedding, code signing, and stripping of non-distributable content (e.g. headers and Swift module metadata) during archiving.

SPM: Manually select https://github.com/attentive-mobile/attentive-ios-sdk in Xcode package dependency UI.

### XCFramework (Manual Integration)

Universal `XCFramework` is supported for consumers on Xcode 26.1.1+.

A pre-built `ATTNSDKFramework.xcframework` is attached to each [GitHub release](https://github.com/attentive-mobile/attentive-ios-sdk/releases). If you cannot use SPM or CocoaPods, you can integrate it manually:

1. Download `ATTNSDKFramework.xcframework.zip` from the desired release and unzip it.
2. Drag the `ATTNSDKFramework.xcframework` folder into your Xcode project navigator.
3. Select your app target, go to **General > Frameworks, Libraries, and Embedded Content**.
4. Ensure `ATTNSDKFramework.xcframework` is listed and set to **"Embed & Sign"**.

> [!WARNING]
> **We strongly recommend using SPM or CocoaPods instead of manual XCFramework integration.** The XCFramework is a dynamic framework, and incorrect embedding can cause App Store submission failures. A common issue is Apple rejecting the archive with:
>
> *"Invalid Bundle. The bundle at 'YourApp.app/Frameworks/ATTNSDKFramework.framework' contains disallowed nested bundles."*
>
> This happens when the framework's `Headers/` and `Modules/` directories are not stripped during archiving. To avoid this, always add the XCFramework through the **General > Frameworks, Libraries, and Embedded Content** UI with **"Embed & Sign"** — do not manually add it via a Copy Files build phase. SPM avoids this entirely because it handles the embedding and stripping automatically.


## Usage

See the [Example Project](https://github.com/attentive-mobile/attentive-ios-sdk/tree/main/Example) for a sample of how the Attentive
iOS SDK is used.

See the [Bonni App](https://github.com/attentive-mobile/attentive-ios-sdk/tree/main/Bonni) for a sample of how the push integration works.

> [!IMPORTANT]
> Please refrain from using any internal or undocumented classes or methods as they may change between releases.

### SDK Logging

In addition to the SDK’s standard logging (e.g., Xcode’s debug console), Attentive iOS SDK logs are also emitted to Apple’s unified logging system. To view them in Console.app, run your app on a simulator or device, open Console, and filter for **attentive-ios-sdk** to see all SDK log output.

## Step 1 - SDK initialization

### Initialize the SDK

**Note** the SDK must be initialized as soon as possible after application startup. This is required for us to properly track metrics and to ensure the SDK functions properly.

The code snippets and examples below assume you are working in Swift or Objective C. To make the SDK available, you need to import the header
file after installing the SDK:

#### Swift
```swift
import ATTNSDKFramework
```

```swift
// Initialize the SDK with your attentive domain, in production mode

  ATTNSDK.initialize(domain: "myCompanyDomain", mode: .production) { result in
    switch result {
    case .success(let sdk):
      self.attentiveSdk = sdk

      // Initialize the AttentiveEventTracker. The AttentiveEventTracker is used to send user events (e.g. a Purchase) to Attentive. It must be set up before it can be used to send events.
      ATTNEventTracker.setup(with: sdk)

    case .failure(let error):
      // Handle init failure
      print("Attentive SDK failed to initialize: \(error)")
    }
  }
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

## Step 2 - Identify the current user

When you gather information about the current user (user ID, email, phone, etc), you can pass it to Attentive for identification purposes via the `identify` function. You can call identify every time to add any additional information about the user.

Here is the list of possible identifiers available in `ATTNIdentifierType`:

| Identifier Name | Constant Name | Type | Description |
| ------------------ | ------------------ | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Client User ID | `clientUserId` | `String` | Your unique identifier for the user. This should be consistent across the user's lifetime. For example, a database id. |
| Phone | `phone` | `String` | The users's phone number in E.164 format |
| Email | `email` | `String` | The users's email |
| Shopify ID | `shopifyId` | `String` | The users's Shopify ID |
| Klaviyo ID | `klaviyoId` | `String` | The users's Klaviyo ID |
| Custom Identifiers | `customIdentifiers` | `[String: String]` | Key-value pairs of custom identifier names and values. The values should be unique to this user. |

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
### Clearing user data

When the user logs out of your application, call `clearUser` to remove all current identifiers **and** detach the push token from the logged-out user. This ensures the previous user no longer receives push notifications on this device.

#### Swift
```swift
sdk.clearUser()
```

#### Objective-C
```objective-c
[sdk clearUser];
```

> **Note:** `clearUser` requires a push token to have been registered (via `registerDeviceToken`) in order to detach it server-side. If no push token is available, identifiers are still cleared locally.

### Update user via email and/or phone

Our SDK supports switching the identified user via email and/or phone (at least one identifier must be provided). Calling this method will clear all identifiers previously associated with the current user (the sdk will automatically call clearUser()), and associate the app with the new identifier(s) you provide. This ensures that all subsequent events and messages are attributed to the newly identified user.

#### Swift
```
// Update user with both email and phone
attentiveSdk.updateUser(email: "user@example.com", phone: "+15551234567") { result in
    switch result {
    case .success:
        // print("User updated successfully with email and phone")
        break
    case .failure(let error):
        // print("User update failed: \(error.localizedDescription)")
        break
    }
}
```

#### Objective-C
```
// Update user with email
[attentiveSdk updateUserWithEmail:@"user@example.com"
                            phone:nil
                         callback:^(ATTNAPIResult *result) {
    if (result.success) {
        // NSLog(@"User updated successfully with email");
    } else {
        // NSLog(@"User update failed: %@", result.error.localizedDescription);
    }
}];
```

### Managing User Identity

As discussed above, the SDK provides three methods for managing user identity within your app:

- **`identify()`** – Add or enrich information about the current user.  
- **`clearUser()`** – Clear all identifiers for the current user (used on logout).  
- **`updateUser()`** – Switch to a different user (automatically calls `clearUser()` first).  

Common use cases:

### 1. Anonymous user (default state)  
No action required. The SDK automatically tracks events as anonymous until identifiers are provided.  

### 2. First login (user provides email and/or phone)  
Call `identify()` to attach identifiers (email, phone, or both) to the current anonymous user.  

```
// first-time login
attentiveSdk?.identify([
  ATTNIdentifierType.email: "user@example.com",
  ATTNIdentifierType.phone: "+15551234567"
])
```

### 3. User logs out  
Call `clearUser()` to remove identifiers.  

``` user logs out
attentiveSdk?.clearUser()
```

### 4. A different user logs in on the same device  
Call `updateUser(email:phone:callback:)`. This clears the old identifiers automatically and sets the new identifiers accordingly.  
```
// switching to a different user on the same device
attentiveSdk?.updateUser(email: "newuser@example.com", phone: "+15559876543") { result in
    switch result {
    case .success:
        print("Switched to new user")
    case .failure(let error):
        print("Failed to update user: \(error.localizedDescription)")
    }
}
```

### Notes  
- If the same person logs in again with the same identifiers, the SDK will continue to treat the device as belonging to them.  
- At least one identifier (`email` or `phone`) must be provided when calling `identify` or `updateUser`.  
- Use `updateUser` only when switching users; otherwise prefer `identify` for enriching the current user’s profile.  

## Step 3 - Record user events

Call Attentive's event functions whenever important events happens in your app, so that Attentive can better understand user behaviors, trigger journeys, and attribute revenue accurately.

The SDK currently supports `ATTNPurchaseEvent`, `ATTNAddToCartEvent`, `ATTNProductViewEvent`, and `ATTNCustomEvent`.

### Event Metadata Fields

#### ATTNItem

| Field              | Type               | Required | Description                          |
| ------------------ | ------------------ | -------- | ------------------------------------ |
| `productId`        | `String`           | Yes      | The product's unique identifier      |
| `productVariantId` | `String`           | Yes      | The product variant's identifier     |
| `price`            | `ATTNPrice`        | Yes      | The item's price                     |
| `productImage`     | `String?`          | No       | URL of the product image             |
| `name`             | `String?`          | No       | The product name                     |
| `quantity`         | `Int`              | No       | The quantity (default: 1)            |
| `category`         | `String?`          | No       | The product category                 |

#### ATTNPrice

| Field      | Type               | Required | Description                                  |
| ---------- | ------------------ | -------- | -------------------------------------------- |
| `price`    | `NSDecimalNumber`  | Yes      | The price value                              |
| `currency` | `String`           | Yes      | The currency code (e.g. `"USD"`)             |

#### ATTNOrder

| Field     | Type     | Required | Description                   |
| --------- | -------- | -------- | ----------------------------- |
| `orderId` | `String` | Yes      | The order's unique identifier |

#### ATTNCart

| Field        | Type      | Required | Description                   |
| ------------ | --------- | -------- | ----------------------------- |
| `cartId`     | `String?` | No       | The cart's unique identifier  |
| `cartCoupon` | `String?` | No       | A coupon code applied to cart |

#### ATTNPurchaseEvent

| Field   | Type          | Required | Description                              |
| ------- | ------------- | -------- | ---------------------------------------- |
| `items` | `[ATTNItem]`  | Yes      | The item(s) purchased                    |
| `order` | `ATTNOrder`   | Yes      | The order associated with the purchase   |
| `cart`  | `ATTNCart?`   | No       | The cart the purchase was made from      |

#### ATTNAddToCartEvent

| Field      | Type          | Required | Description                            |
| ---------- | ------------- | -------- | -------------------------------------- |
| `items`    | `[ATTNItem]`  | Yes      | The item(s) added to cart              |
| `deeplink` | `String?`     | No       | A deeplink URL to the product          |

#### ATTNProductViewEvent

| Field      | Type          | Required | Description                            |
| ---------- | ------------- | -------- | -------------------------------------- |
| `items`    | `[ATTNItem]`  | Yes      | The item(s) viewed                     |
| `deeplink` | `String?`     | No       | A deeplink URL to the product          |

#### ATTNCustomEvent

| Field        | Type                | Required | Description                                                  |
| ------------ | ------------------- | -------- | ------------------------------------------------------------ |
| `type`       | `String`            | Yes      | The event name (case-sensitive, no special characters)        |
| `properties` | `[String: String]`  | Yes      | Key-value pairs of metadata (keys and values case-sensitive)  |

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

You can also implement `CustomEvent` to send application-specific event schemas. These are simply key/value pairs which will be transmitted and stores in Attentive's systems for later use. Please discuss with your CSM to understand how and where these events can be use in orchestration.

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

## Step 4 - Integrate With Push
#### Swift

Show push permission prompt:
```
attentiveSdk?.registerForPushNotifications { granted, error in
    if let error = error {
        // Handle error (e.g. logging)
    }
    if granted {
        // Permission granted, proceed with registration-dependent logic
    } else {
        // Permission denied
    }
}
```

Push registration:
```
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
  UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
    guard let self = self else { return }
    let authStatus = settings.authorizationStatus
    attentiveSdk?.registerDeviceToken(deviceToken, authorizationStatus: authStatus, callback: { data, url, response, error in
      DispatchQueue.main.async {
        self.attentiveSdk?.handleRegularOpen(authorizationStatus: authStatus)
      }
    })
  }
}
```

Handle when push registration fails:
```
func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
    attentiveSdk?.failedToRegisterForPush(error)
}
```

Handle incoming push:
```
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let authStatus = settings.authorizationStatus
      DispatchQueue.main.async {
        switch UIApplication.shared.applicationState {
        case .active:
          self.attentiveSdk?.handleForegroundPush(response: response, authorizationStatus: authStatus)

        case .background, .inactive:
          self.attentiveSdk?.handlePushOpen(response: response, authorizationStatus: authStatus)

        @unknown default:
          self.attentiveSdk?.handlePushOpen(response: response, authorizationStatus: authStatus)
        }
      }
    }
    completionHandler()
}
```

#### Objective-C

Show push permission prompt:
```
[self.attentiveSdk registerForPushNotifications];
```

Handle when push registration fails:
```
[self.attentiveSdk registerForPushFailed:error];
```

Handle incoming push: 
```
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    [[UNUserNotificationCenter currentNotificationCenter]
      getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {

        UNAuthorizationStatus authStatus = settings.authorizationStatus;

        dispatch_async(dispatch_get_main_queue(), ^{
            UIApplicationState state = [UIApplication sharedApplication].applicationState;
            switch (state) {
                case UIApplicationStateActive:
                    [self.attentiveSdk
                        handleForegroundPushWithResponse:response
                                 authorizationStatus:authStatus];
                    break;

                case UIApplicationStateBackground:
                case UIApplicationStateInactive:
                    [self.attentiveSdk
                        handlePushOpenWithResponse:response
                            authorizationStatus:authStatus];
                    break;

                default:
                    [self.attentiveSdk
                        handlePushOpenWithResponse:response
                            authorizationStatus:authStatus];
                    break;
            }
        });
    }];
    completionHandler();
}
```

#### Sample push payload with deep link and image support

```
{
  "aps": {
    "alert": {
      "title": "Welcome to Attentive",
      "body": "Get 10% off your first in-app purchase!"
    },
    "sound": "default",
    "mutable-content": 1
  },
  "attentiveCallbackData": {
    "attentiveData": "<base64-encoded attentive payload>",
    "attentive_open_action_url": "https://www.example.com/promo",
    "attentive_message_title": "Welcome to Attentive",
    "attentive_image_url": "https://cdn.example.com/images/promo-banner.jpg",
    "attentive_message_body": "Get 10% off your first in-app purchase!"
  }
}
```

### Deep Link Support

Our SDK does not open URLs directly. Instead, it extracts and broadcasts a valid deep-link URL whenever a notification is tapped. Your app can then decide when and how to handle it (e.g. navigate immediately, or store it if the user is logged out).

#### Option 1: Observe the ATTNSDKDeepLinkReceived notification
```
NotificationCenter.default.addObserver(
 self,
 selector: #selector(didReceiveDeepLink(_:)),
 name: .ATTNSDKDeepLinkReceived,
 object: nil
)

@objc private func didReceiveDeepLink(_ notification: Notification) {
  guard let url = notification.userInfo?["attentivePushDeeplinkUrl"] as? URL else { return }
  // handle navigating to the link in your app
}
```

#### Option 2: Consume deep link when your app is ready to navigate. This will consume and delete the deep link stored in SDK
```
let sdk = ATTNSDK(domain: "YOUR_DOMAIN", mode: .production)
attentiveSdk = sdk

if let url = attentiveSdk.consumeDeepLink() {
  // handle navigating to the link in your app
}
```

## Step 5 - Email & SMS Subscription Support

### Manage subscriptions for email and phone numbers

Our SDK allows you to directly manage marketing subscriptions for emails and phone numbers. Your app is solely responsible for displaying any required legal information. To opt users in or out, you must provide at least one of either an email address or a phone number. Phone numbers must be in E.164 format.

Examples for creating or removing a subscription (opt in with email, opt out with phone number):

#### Swift
```
let attentiveSdk = ATTNSDK(domain: "YOUR_DOMAIN", mode: .production)

// Opt in a user using their email address and phone.

attentiveSdk.optInMarketingSubscription(email: "user@example.com", phone: "+15551234567") { _, _, response, error in
    if error == nil {
        // print("Opt-in successful")
    } else {
        // print("Opt-in failed: \(error)")
    }
}

// You can also opt in using only a single identifier (email or phone).
attentiveSdk.optInMarketingSubscription(email: "seconduser@example.com") { _, _, response, error in
    if error == nil {
        // print("Opt-in successful")
    } else {
        // print("Opt-in failed: \(error)")
    }
}

// Opt out a user who previously opted in (via email, phone, or both).
// The same parameters apply here. Pass whichever identifiers were used for opt-in.
attentiveSdk.optOutMarketingSubscription(email: "user@example.com", phone: "+15551234567") { _, _, response, error in
    if error == nil {
        // print("Opt-out successful")
    } else {
        // print("Opt-out failed: \(error)")
    }
}
```

> [!IMPORTANT]
> Please do not include a static/hard-coded SMS or email while testing as this will cause all push tokens to associate to the same user profile.

#### Objective-C
```
ATTNSDK *attentiveSdk = [[ATTNSDK alloc] initWithDomain:@"YOUR_DOMAIN"
                                                   mode:ATTNSDKModeProduction];
// Opt in with email
[attentiveSdk optInMarketingSubscriptionWithEmail:@"user@example.com"
                                         callback:^(NSData *data, NSURL *url, NSURLResponse *response, NSError *error) {
    if (!error) {
        // NSLog(@"Email opt-in successful");
    } else {
        // NSLog(@"Email opt-in failed: %@", error);
    }
}];

// Opt out with phone
[attentiveSdk optOutMarketingSubscriptionWithPhone:@"+15551234567"
                                          callback:^(NSData *data, NSURL *url, NSURLResponse *response, NSError *error) {
    if (!error) {
        // NSLog(@"Phone opt-out successful");
    } else {
        // NSLog(@"Phone opt-out failed: %@", error);
    }
}];
```

## Step 6 (optional) - Show Creatives

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
      if ([triggerStatus isEqualToString:ATTNCreativeTriggerStatus.opened]) {
        NSLog(@"Opened the Creative!");
      } else if ([triggerStatus isEqualToString:ATTNCreativeTriggerStatus.notOpened]) {
        NSLog(@"Couldn't open the Creative!");
      } else if ([triggerStatus isEqualToString:ATTNCreativeTriggerStatus.closed]) {
        NSLog(@"Closed the Creative!");
      } else if ([triggerStatus isEqualToString:ATTNCreativeTriggerStatus.notClosed]) {
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

### Trigger a Specific Creative

You can display a specific sign-up unit by passing its creative ID to the `trigger` method. This is useful when you want to show different creatives based on where the user is in your app (e.g., a different sign-up unit on the home screen vs. a product page).

#### Swift

```swift
// Trigger a specific creative by ID
sdk.trigger(view, creativeId: "YOUR_CREATIVE_ID")

// Trigger a specific creative by ID with a completion handler
sdk.trigger(view, creativeId: "YOUR_CREATIVE_ID") { status in
  switch status {
  case ATTNCreativeTriggerStatus.opened:
    print("Opened the Creative!")
  case ATTNCreativeTriggerStatus.notOpened:
    print("Couldn't open the Creative!")
  case ATTNCreativeTriggerStatus.closed:
    print("Closed the Creative!")
  case ATTNCreativeTriggerStatus.notClosed:
    print("Couldn't close the Creative!")
  default:
    break
  }
}
```

#### Objective-C

```objective-c
// Trigger a specific creative by ID
[sdk trigger:self.view creativeId:@"YOUR_CREATIVE_ID"];

// Trigger a specific creative by ID with a completion handler
[sdk trigger:self.view creativeId:@"YOUR_CREATIVE_ID" handler:^(NSString *triggerStatus) {
  if ([triggerStatus isEqualToString:ATTNCreativeTriggerStatus.opened]) {
    NSLog(@"Opened the Creative!");
  } else if ([triggerStatus isEqualToString:ATTNCreativeTriggerStatus.notOpened]) {
    NSLog(@"Couldn't open the Creative!");
  } else if ([triggerStatus isEqualToString:ATTNCreativeTriggerStatus.closed]) {
    NSLog(@"Closed the Creative!");
  } else if ([triggerStatus isEqualToString:ATTNCreativeTriggerStatus.notClosed]) {
    NSLog(@"Couldn't close the Creative!");
  }
}];
```

### Skip Fatigue on Creative

For debugging purposes, you can skip fatigue rule evaluation to show your creative every time. Default value is `false`.

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

## Other functionalities

### Switch to another domain

Reinitialize the SDK with a different domain. Please contact your CSM for this use case.

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


## Changelog

Click [here](https://github.com/attentive-mobile/attentive-ios-sdk/blob/main/CHANGELOG.md) for a complete change log of every released version.
