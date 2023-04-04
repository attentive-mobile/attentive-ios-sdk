//
//  ATTNOrder.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/16/22.
//

#import "ATTNOrder.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ATTNOrder

- (instancetype)initWithOrderId:(NSString *)orderId {
  if (self = [super init]) {
    self->_orderId = orderId;
  }

  return self;
}

@end

NS_ASSUME_NONNULL_END
