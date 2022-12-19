//
//  ATTNOrder.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/16/22.
//

#import "ATTNOrder.h"

@implementation ATTNOrder

- (instancetype)initWithOrderId:(NSString*)orderId {
    if (self = [super init]) {
        self->_orderId = orderId;
    }
    
    return self;
}

@end
