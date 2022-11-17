//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>

@interface ATTNUserIdentifiers : NSObject

- (nonnull id)initWithUserIdentifiers:(nonnull NSDictionary *) userIdentifiers;

// Your unique identifier for the user - this should be consistent across the user's lifetime, for example a database id
@property (readonly, nonnull) NSString * clientUserId;

// The user's email
@property (readonly, nullable) NSString * email;

// The user's phone number in E.164 format
@property (readonly, nullable) NSString * phone;

// The user's Klaviyo ID
@property (readonly, nullable) NSString * klaviyoId;

// The user's Shopify Customer ID
@property (readonly, nullable) NSString * shopifyId;

// Key-value pairs of custom identifier names and values to associate with this user
@property (readonly, nullable) NSDictionary<NSString *, NSString *> * customIdentifiers;

@end
