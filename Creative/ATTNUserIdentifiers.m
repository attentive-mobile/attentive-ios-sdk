//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>

#import "ATTNUserIdentifiers.h"

@implementation ATTNUserIdentifiers


- (id)initWithUserIdentifiers:(nonnull NSDictionary *) userIdentifiers {
    self = [super init];
    
    _clientUserId = userIdentifiers[@"clientUserId"];
    _phone = userIdentifiers[@"phone"];
    _email = userIdentifiers[@"email"];
    _shopifyId = userIdentifiers[@"shopifyId"];
    _klaviyoId = userIdentifiers[@"klaviyoId"];
    _customIdentifiers = [NSDictionary<NSString *, NSString *> dictionaryWithDictionary:userIdentifiers[@"customIdentifiers"]];
    
    return self;
}

@end
