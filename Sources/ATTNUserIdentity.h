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

NS_ASSUME_NONNULL_END


@interface ATTNUserIdentity : NSObject

- (nonnull id)init;

- (nonnull id)initWithIdentifiers:(nonnull NSDictionary *) identifiers;

- (void)validateIdentifiers:(nonnull NSDictionary *) identifiers;

- (void)mergeIdentifiers:(nonnull NSDictionary *) newIdentifiers;

@property (nonnull) NSDictionary * identifiers;

@end
