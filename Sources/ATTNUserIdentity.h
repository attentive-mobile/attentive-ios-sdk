//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

extern NSString * const IDENTIFIER_TYPE_CLIENT_USER_ID;
extern NSString * const IDENTIFIER_TYPE_PHONE;
extern NSString * const IDENTIFIER_TYPE_EMAIL;
extern NSString * const IDENTIFIER_TYPE_SHOPIFY_ID;
extern NSString * const IDENTIFIER_TYPE_KLAVIYO_ID;
extern NSString * const IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS;


@interface ATTNUserIdentity : NSObject

@property NSDictionary * identifiers;


- (id)init;

- (id)initWithIdentifiers:(NSDictionary *) identifiers;

- (void)validateIdentifiers:(NSDictionary *) identifiers;

- (void)mergeIdentifiers:(NSDictionary *) newIdentifiers;

@end


NS_ASSUME_NONNULL_END
