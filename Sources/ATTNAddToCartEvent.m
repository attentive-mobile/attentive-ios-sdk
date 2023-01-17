//
//  ATTNAddToCartEvent.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 1/17/23.
//

#import "ATTNEvent.h"
#import "ATTNAddToCartEvent.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ATTNAddToCartEvent

- (instancetype)initWithItems:(NSArray<ATTNItem *> *)items {
    if (self = [super init]) {
        self->_items = items;
    }
    
    return self;
}

@end

NS_ASSUME_NONNULL_END
