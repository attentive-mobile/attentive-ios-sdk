//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>

#import "ATTNUserIdentity.h"

// Your unique identifier for the user - this should be consistent across the user's lifetime, for example a database id
const NSString * IDENTIFIER_TYPE_CLIENT_USER_ID = @"clientUserId";
// The user's phone number in E.164 format
const NSString * IDENTIFIER_TYPE_PHONE = @"phone";
// The user's email
const NSString * IDENTIFIER_TYPE_EMAIL = @"email";
// The user's Shopify Customer ID
const NSString * IDENTIFIER_TYPE_SHOPIFY_ID = @"shopifyId";
// The user's Klaviyo ID
const NSString * IDENTIFIER_TYPE_KLAVIYO_ID = @"klaviyoId";
// Key-value pairs of custom identifier names and values (both NSStrings) to associate with this user
const NSString * IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS = @"customIdentifiers";


@implementation ATTNUserIdentity


- (id)initWithUserIdentifiers:(nonnull NSDictionary *) userIdentifiers {
    self = [super init];
    
    _userIdentifiers = userIdentifiers;
    
    return self;
}

@end
