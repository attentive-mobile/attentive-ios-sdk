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


- (id)initWithIdentifiers:(nonnull NSDictionary *) identifiers {
    self = [super init];
    
    [self validateIdentifiers:identifiers];
    _identifiers = identifiers;
    
    return self;
}

- (void)validateIdentifiers:(nonnull NSDictionary *) identifiers {
    [ATTNParameterValidation verifyString:identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID] inputName:IDENTIFIER_TYPE_CLIENT_USER_ID];
    [ATTNParameterValidation verifyString:identifiers[IDENTIFIER_TYPE_PHONE] inputName:IDENTIFIER_TYPE_PHONE];
    [ATTNParameterValidation verifyString:identifiers[IDENTIFIER_TYPE_EMAIL] inputName:IDENTIFIER_TYPE_EMAIL];
    [ATTNParameterValidation verifyString:identifiers[IDENTIFIER_TYPE_SHOPIFY_ID] inputName:IDENTIFIER_TYPE_SHOPIFY_ID];
    [ATTNParameterValidation verifyString:identifiers[IDENTIFIER_TYPE_KLAVIYO_ID] inputName:IDENTIFIER_TYPE_KLAVIYO_ID];
    [ATTNParameterValidation verify1DStringDictionary:identifiers[IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS] inputName:IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS];
}

@end
