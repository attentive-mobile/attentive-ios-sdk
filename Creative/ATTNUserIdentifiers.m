//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>

#import "ATTNUserIdentifiers.h"

@implementation ATTNUserIdentifiers

- (id)initWithAppUserId:(nonnull NSString *)appUserId {
    return [self initWithAppUserId:appUserId andPhone:nil andEmail:nil andShopifyId:nil andKlaviyoId:nil andCustomIdentifiers:nil];
}

- (id)initWithAppUserId:(nonnull NSString *) appUserId andPhone:(nullable NSString *) phone andEmail:(nullable NSString *) email andShopifyId:(nullable NSString *) shopifyId andKlaviyoId:(nullable NSString *) klaviyoId andCustomIdentifiers:(nullable NSDictionary *) customIdentifiers {
    self = [super init];
    
    _appUserId = appUserId;
    _phone = phone;
    _email = email;
    _shopifyId = shopifyId;
    _klaviyoId = klaviyoId;
    if (customIdentifiers != nil) {
        _customIdentifiers = [[NSDictionary alloc] initWithDictionary:customIdentifiers];
    }
    
    return self;
}

@end
