# Attentive iOS SDK

The Attentive mobile SDK provides functionalities like gathering user identity, collecting event data, and rendering creatives for your app. This enables cross-platform journeys, enhanced reporting, and revenue attributions.

## Prerequisites

### Cocoapods for 2.0.2-beta.2

The attentive-ios-sdk is available through [CocoaPods](https://cocoapods.org). To install the SDK in a separate project using Cocoapods, include the pod in your application’s Podfile:

```ruby
target 'MyApp' do
  pod 'attentive-ios-sdk', '2.0.2-beta.2'
end
```

And then make sure to run:

```ruby
pod install
```


### Swift Package Manager

We also support adding the dependency via Swift Package Manager.
SPM: Manually select https://github.com/attentive-mobile/attentive-ios-sdk in Xcode package dependency UI and then specify branch name: beta/2.0.2-beta.2


## Usage

See the [Example Project](https://github.com/attentive-mobile/attentive-ios-sdk/tree/main/Example) for a sample of how the Attentive
iOS SDK is used.

See the [Bonni App](https://github.com/attentive-mobile/attentive-ios-sdk/tree/beta/2.0.2-beta.2/Bonni) for a sample of how the push integration works.

> [!IMPORTANT]
> Please refrain from using any internal or undocumented classes or methods as they may change between releases.

## Step 1 - SDK initialization

### Initialize the SDK

The code snippets and examples below assume you are working in Swift or Objective C. To make the SDK available, you need to import the header
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

If the user "logs out" of your application, you can call `clearUser` to remove all current identifiers.

#### Swift
```swift
sdk.clearUser()
```

#### Objective-C
```objective-c
[sdk clearUser];
```

## Step 3 - Record user events

Call Attentive's event functions whenever important events happens in your app, so that Attentive can better understand user behaviors, trigger journeys, and attribute revenue accurately.

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

## Step 5 - Add Image Support for Push Notifications

To display images in push notifications sent via Attentive, you’ll need to create a Notification Service Extension (NSE) in your app if you haven’t already. This is a standard iOS feature for customizing push content and you can refer to Apple’s documentation or online tutorials for setup. Once the extension is in place, update your **Notification Service Extension** to handle `attentive_image_url` as below.

You can reference `Bonni/ATTNNotificationService/NotificationService.swift` and the Bonni app `Bonni/Bonni.xcodeproj` for a complete example of how the Notification Service Extension is set up in Swift.

### Update `NotificationService.swift`

In your extension target, update the `didReceive` method:

#### Swift
```
guard
  let callbackData = bestAttemptContent.userInfo["attentiveCallbackData"] as? [String: Any],
  let imageURLString = callbackData["attentive_image_url"] as? String,
  let imageURL = URL(string: imageURLString)
else {
  // Error handling
}

downloadImageAttachment(from: imageURL) { attachment in
  if let attachment = attachment {
    bestAttemptContent.attachments = [attachment]
  }
  contentHandler(bestAttemptContent)
}
```
Also add the downloadImageAttachment helper:
```
private func downloadImageAttachment(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
  URLSession.shared.downloadTask(with: url) { downloadedUrl, _, _ in
    guard let downloadedUrl else {
      completion(nil)
      return
    }

    let fileExtension = url.pathExtension.isEmpty ? "tmp" : url.pathExtension
    let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "." + fileExtension)

    do {
      try FileManager.default.moveItem(at: downloadedUrl, to: tmpURL)
      let attachment = try UNNotificationAttachment(identifier: "image", url: tmpURL, options: nil)
      completion(attachment)
    } catch {
      completion(nil)
    }
  }.resume()
}
```

#### Objective-C
```
NSDictionary *callbackData = request.content.userInfo[@"attentiveCallbackData"];
NSString *imageURLString = callbackData[@"attentive_image_url"];
NSURL *imageURL = [NSURL URLWithString:imageURLString];

if (imageURL) {
    [self downloadImageAttachmentFromURL:imageURL completion:^(UNNotificationAttachment *attachment) {
        if (attachment) {
            bestAttemptContent.attachments = @[attachment];
        }
        contentHandler(bestAttemptContent);
    }];
} else {
    contentHandler(bestAttemptContent);
}

// Helper method:
- (void)downloadImageAttachmentFromURL:(NSURL *)url
                            completion:(void (^)(UNNotificationAttachment *attachment))completion {
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url
        completionHandler:^(NSURL *downloadedURL, NSURLResponse *response, NSError *error) {
            if (!downloadedURL) {
                completion(nil);
                return;
            }

            NSString *fileExtension = url.pathExtension.length > 0 ? url.pathExtension : @"tmp";
            NSString *uniqueName = [NSString stringWithFormat:@"%@.%@", [NSUUID UUID].UUIDString, fileExtension];
            NSURL *tmpDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
            NSURL *tmpFileURL = [tmpDirectory URLByAppendingPathComponent:uniqueName];

            NSError *fileError = nil;
            [[NSFileManager defaultManager] moveItemAtURL:downloadedURL toURL:tmpFileURL error:&fileError];

            if (fileError) {
                completion(nil);
                return;
            }

            UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"image"
                                                                                                   URL:tmpFileURL
                                                                                               options:nil
                                                                                                 error:nil];
            completion(attachment);
        }];
    [task resume];
}
```

## Other functionality

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
