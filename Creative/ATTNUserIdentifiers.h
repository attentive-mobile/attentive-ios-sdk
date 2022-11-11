//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>

@interface ATTNUserIdentifiers : NSObject

- (nonnull id)initWithAppUserId:(nonnull NSString *)appUserId;

- (nonnull id)initWithAppUserId:(nonnull NSString *) appUserId andPhone:(nullable NSString *) phone andEmail:(nullable NSString *) email andShopifyId:(nullable NSString *) shopifyId andKlaviyoId:(nullable NSString *) klaviyoId andCustomIdentifiers:(nullable NSDictionary *) customIdentifiers;

@property (readonly, nonnull) NSString * appUserId;
@property (readonly, nullable) NSString * email;
@property (readonly, nullable) NSString * phone;
@property (readonly, nullable) NSString * klaviyoId;
@property (readonly, nullable) NSString * shopifyId;
@property (readonly, nullable) NSDictionary * customIdentifiers;

@end
