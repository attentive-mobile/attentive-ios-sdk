//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>
#import "ATTNParameterValidation.h"


NS_ASSUME_NONNULL_BEGIN

extern const NSString * IDENTIFIER_TYPE_CLIENT_USER_ID;
extern const NSString * IDENTIFIER_TYPE_PHONE;
extern const NSString * IDENTIFIER_TYPE_EMAIL;
extern const NSString * IDENTIFIER_TYPE_SHOPIFY_ID;
extern const NSString * IDENTIFIER_TYPE_KLAVIYO_ID;
extern const NSString * IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS;

NS_ASSUME_NONNULL_END


@interface ATTNUserIdentity : NSObject

- (nonnull id)initWithIdentifiers:(nonnull NSDictionary *) identifiers;

- (void)validateIdentifiers:(nonnull NSDictionary *) identifiers;

@property (nonnull) NSDictionary * identifiers;

@end
