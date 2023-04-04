//
//  ATTNPrice.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/16/22.
//

#import "ATTNPrice.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ATTNPrice

- (instancetype)initWithPrice:(NSDecimalNumber*)price currency:(NSString*)currency {
    if (self = [super init]) {
        self->_price = price;
        self->_currency = currency;
    }
    
    return self;
}

@end

NS_ASSUME_NONNULL_END
