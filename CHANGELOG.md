## [1.0.0-beta.1](https://github.com/attentive-mobile/attentive-ios-sdk/compare/0.6.0...1.0.0-beta.1) (2024-06-27)

### Breaking Changes
* Upgraded SDK minimum deployment target from iOS 11 to iOS 14 to support new features from iOS Frameworks.

### Feature
* Add a log level of verbose/standard/light to the SDK Config ([101](https://github.com/attentive-mobile/attentive-ios-sdk/pull/101)) ([0a40997](https://github.com/attentive-mobile/attentive-ios-sdk/commit/0a40997e62803d83731cc35d3b9c95aa5996893f))
* Create (or update) test suite ([100](https://github.com/attentive-mobile/attentive-ios-sdk/pull/100)) ([4e562cd](https://github.com/attentive-mobile/attentive-ios-sdk/commit/4e562cd93f4e17f6f7fd3498076895ec5e8e6fa8))
* Force show creatives on client apps for testing ([97](https://github.com/attentive-mobile/attentive-ios-sdk/pull/97)) ([1a2d81c](https://github.com/attentive-mobile/attentive-ios-sdk/commit/1a2d81cbfbb440638f5c5342225aeb58f11a236e))
* Mobile App Domain Switching ([95](https://github.com/attentive-mobile/attentive-ios-sdk/pull/95)) ([e12028d](e12028d7892ca5fbd785e26b05dfeda4ab187024))

## [0.6.0](https://github.com/attentive-mobile/attentive-ios-sdk/compare/0.5.1...0.6.0) (2024-06-13)

### Breaking Changes
* `ATTNEventTracker.sharedInstance()` returns now and Optional. Update your codebase accordingly to avoid operating over a nil instance.
* For **SPM**, Objective-C target **ATTNSDKFrameworkObjc** was added due to mixed languages limitations in the **Sources/** folder. Please use `import ATTNSDKFrameworkObjc` to access the following global constants.

  | Creative   |
  |------------|
  | CREATIVE_TRIGGER_STATUS_OPENED |
  | CREATIVE_TRIGGER_STATUS_CLOSED |
  | CREATIVE_TRIGGER_STATUS_NOT_OPENED |
  | CREATIVE_TRIGGER_STATUS_NOT_CLOSED |

  | Identity   |
  |------------|
  | IDENTIFIER_TYPE_CLIENT_USER_ID |
  | IDENTIFIER_TYPE_PHONE |
  | IDENTIFIER_TYPE_EMAIL |
  | IDENTIFIER_TYPE_SHOPIFY_ID |
  | IDENTIFIER_TYPE_KLAVIYO_ID |
  | IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS |

### Bug Fixes

* App SDK CocoaPods Download Error ([91](https://github.com/attentive-mobile/attentive-ios-sdk/pull/91)) ([835836f](https://github.com/attentive-mobile/attentive-ios-sdk/commit/835836f8b7268bdb357d2c88fdefea67571ff2de))
  * [**Deprecation**] Cocoapods `attentive-ios-sdk` podspec deprecated in favor of `ATTNSDKFramework`. A Warning will be displayed in the logs after `pod install` or `pod update`.

### Feature

* Migrate SDK to Swift ([92](https://github.com/attentive-mobile/attentive-ios-sdk/pull/92)) ([1c61845](https://github.com/attentive-mobile/attentive-ios-sdk/commit/1c61845c024ebd26ba4b0965ec4939789e76b097))

    * [**Deprecation**] In `ATTNEventTracker`, deprecated `init(domain: String, mode: String)` in favor of `init(domain: String, mode: ATTNSDKMode)`
    * [**Deprecation**] In `ATTNEventTracker`, deprecated `record(_ event: ATTNEvent)` in favor of `record(event: ATTNEvent)`
    * [**Deprecation**] `ATTNCreativeTriggerStatus` created in order to deprecated **Creative** global constants.

      | Global Constants | ATTNCreativeTriggerStatus |  
      |------------|------------|
      | CREATIVE_TRIGGER_STATUS_OPENED | ATTNCreativeTriggerStatus.opened |
      | CREATIVE_TRIGGER_STATUS_CLOSED | ATTNCreativeTriggerStatus.closed |
      | CREATIVE_TRIGGER_STATUS_NOT_OPENED | ATTNCreativeTriggerStatus.notOpened | 
      | CREATIVE_TRIGGER_STATUS_NOT_CLOSED | ATTNCreativeTriggerStatus.notClosed |

    * [**Deprecation**] `ATTNIdentifierType` created in order to deprecated **Identity** global constants.
      | Global Constants | ATTNIdentifierType |  
      |------------|------------|
      | IDENTIFIER_TYPE_CLIENT_USER_ID | ATTNIdentifierType.clientUserId |
      | IDENTIFIER_TYPE_PHONE | ATTNIdentifierType.phone |
      | IDENTIFIER_TYPE_EMAIL | ATTNIdentifierType.email | 
      | IDENTIFIER_TYPE_SHOPIFY_ID | ATTNIdentifierType.shopifyId |
      | IDENTIFIER_TYPE_KLAVIYO_ID | ATTNIdentifierType.klaviyoId | 
      | IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS | ATTNIdentifierType.customIdentifiers |
    

## [0.5.1](https://github.com/attentive-mobile/attentive-ios-sdk/compare/0.5.0...0.5.1) (2024-05-22)

### Bug Fixes

* Fix project structure to push to cocoapods and SPM from one codebase ([83](https://github.com/attentive-mobile/attentive-ios-sdk/pull/83)) ([d2eaaa1](https://github.com/attentive-mobile/attentive-ios-sdk/commit/d2eaaa181f4d4a2e5b99b8a1e83c447f2e681be1))

### Feature

* Update documentation to make identify signature more clear ([84](https://github.com/attentive-mobile/attentive-ios-sdk/pull/84)) ([46691f2](https://github.com/attentive-mobile/attentive-ios-sdk/commit/46691f276e02add53c6f6a0af5cd1c13c04c9497))
