//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>

#import "ATTNParameterValidation.h"
#import "ATTNUserIdentity.h"

// Your unique identifier for the user - this should be consistent across the user's lifetime, for example a database id
NSString * const IDENTIFIER_TYPE_CLIENT_USER_ID = @"clientUserId";
// The user's phone number in E.164 format
NSString * const IDENTIFIER_TYPE_PHONE = @"phone";
// The user's email
NSString * const IDENTIFIER_TYPE_EMAIL = @"email";
// The user's Shopify Customer ID
NSString * const IDENTIFIER_TYPE_SHOPIFY_ID = @"shopifyId";
// The user's Klaviyo ID
NSString * const IDENTIFIER_TYPE_KLAVIYO_ID = @"klaviyoId";
// Key-value pairs of custom identifier names and values (both NSStrings) to associate with this user
NSString * const IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS = @"customIdentifiers";


@implementation ATTNUserIdentity

- (id)init {
    _identifiers = @{};
    return [super init];
}

- (id)initWithIdentifiers:(nonnull NSDictionary *) identifiers {
    self = [super init];
    
    [self validateIdentifiers:identifiers];
    _identifiers = identifiers;
    
    return self;
}

- (void)mergeIdentifiers:(nonnull NSDictionary *) newIdentifiers {
    [self validateIdentifiers:newIdentifiers];

    NSMutableDictionary *currentIdentifiersCopy = [_identifiers mutableCopy];
    [currentIdentifiersCopy addEntriesFromDictionary:newIdentifiers];
    _identifiers = currentIdentifiersCopy;
}

- (void)validateIdentifiers:(nonnull NSDictionary *) identifiers {
    [ATTNParameterValidation verifyStringOrNil:identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID] inputName:IDENTIFIER_TYPE_CLIENT_USER_ID];
    [ATTNParameterValidation verifyStringOrNil:identifiers[IDENTIFIER_TYPE_PHONE] inputName:IDENTIFIER_TYPE_PHONE];
    [ATTNParameterValidation verifyStringOrNil:identifiers[IDENTIFIER_TYPE_EMAIL] inputName:IDENTIFIER_TYPE_EMAIL];
    [ATTNParameterValidation verifyStringOrNil:identifiers[IDENTIFIER_TYPE_SHOPIFY_ID] inputName:IDENTIFIER_TYPE_SHOPIFY_ID];
    [ATTNParameterValidation verifyStringOrNil:identifiers[IDENTIFIER_TYPE_KLAVIYO_ID] inputName:IDENTIFIER_TYPE_KLAVIYO_ID];
    [ATTNParameterValidation verify1DStringDictionaryOrNil:identifiers[IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS] inputName:IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS];
}


@end
