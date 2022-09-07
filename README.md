# Attentive Mobile SDK

The Attentive Mobile SDK is intended to be used to render creative units in mobile gaming applications.

## Static landing page to render creative

The SDK works by rendering a web view that loads an index.html page stored [here](https://s3.console.aws.amazon.com/s3/object/attn.tv?prefix=mobile-gaming%2Findex.html&region=us-east-1#). This index.html page dynamically loads the dtag.js for whatever company domain is passed as a query param to the request for the index.html page. We also include logic to set the `__attentive_client_user_id` browser cookie to whatever query param is passed to `app_user_id` and to hash this id to a visitorId (the `__attentive_id` browser cookie) so that we can be sure properly handle fatigue for user that have already subscribed.

## Installation and Example of calling the SDK trigger function

The attentive-mobile-sdk is available through [CocoaPods](https://cocoapods.org). To install the SDK in a separate project using Cocoapods, simply run:

```
> pod install attentive-mobile-sdk
```

Additionally, if a new version of the SDK is available, it can be updated using:

```
> pod update attentive-mobile-sdk
```

To make the SDK available, you need to import the header file after installing the SDK:

```
#import "attentive_mobile_sdk/attentive-mobile-sdk-umbrella.h"
```

The SDK can then be initialized and called for a specific company domain and app user:

```
SDK *sdk = [[SDK alloc] initWithDomain:@"${companyDomain}"];
[sdk identify:@"${appUserId}"];
[sdk trigger:self.view];
```

Before attaching the web view to whatever view is passed to trigger function, we first identify whether or not the creative is loaded in the web view. This allows us to decide whether or not to attach the web view based of the fatigue of the creative.

## Publishing the SDK 

In order to publish the SDK first register your user:

```
> pod trunk register ${email}@attentivemobile.com '${Your Name}' --description='macbook air'
```

and then run

```
> pod trunk push --allow-warnings
```

It is necessary to have created a release tag/version prior to publishing and to update the podspec file in the SDK. The release tag/version can be done directly in github under releases. 

## Author

Ivan Loughman-Pawelko, iloughman@attentivemobile.com

## License

attentive-mobile-sdk is available under the MIT license. See the LICENSE file for more info.


