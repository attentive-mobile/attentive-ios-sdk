# Attentive IOS SDK

The Attentive IOS SDK provides the functionality to render Attentive creative units in IOS mobile applications.


## Installation

The attentive-ios-sdk is available through [CocoaPods](https://cocoapods.org). To install the SDK in a separate project using Cocoapods, include the pod in your application’s Podfile:

```
target ‘MyApp’ do
  pod ‘attentive-ios-sdk’
end
```

And then make sure to run:

```
pod install
```

Additionally, if a new version of the SDK is available, it can be updated using:
```
pod update attentive-ios-sdk
```

## Usage
See the [Example Project](https://github.com/attentive-mobile/attentive-ios-sdk/tree/main/Example) for a sample of how the Attentive IOS SDK is used.

The code snippets and examples below assume you are working in Objective C. To make the SDK available, you need to import the header file after installing the SDK:
```objectiveC
#import "attentive_ios_sdk/attentive-ios-sdk-umbrella.h"
```

The SDK can then be initialized and called for a specific company domain and app user:

```objectiveC
// Initialize the SDK with your attentive domain, in production mode
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"myCompanyDomain"];

// Before loading the creative, you will need to register the User's ID
[sdk identify:@"myAppUserId"];

// Load and render the creative
[sdk trigger:self.view];
```

Additionally, it is possible to initialize the SDK in debug mode for more information about your creative and filtering rules:
```objectiveC
ATTNSDK *sdk = [[ATTNSDK alloc] initWithDomain:@"myCompanyDomain" mode:@"debug"];
```
