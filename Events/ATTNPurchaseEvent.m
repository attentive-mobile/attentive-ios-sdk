//
//  ATTNPurchaseEvent.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/7/22.
//

#import "ATTNEvent.h"
#import "ATTNPurchaseEvent.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ATTNPurchaseEvent

- (instancetype)initWithItems:(NSArray<ATTNItem*>*)items order:(ATTNOrder*)order {
    if (self = [super init]) {
        self->_items = items;
        self->_order = order;
    }
    
    return self;
}

@end

NS_ASSUME_NONNULL_END
