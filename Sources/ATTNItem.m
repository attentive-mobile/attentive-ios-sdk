//
//  ATTNItem.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/16/22.
//

#import "ATTNItem.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ATTNItem

- (instancetype)initWithProductId:(NSString *)productId productVariantId:(NSString *)productVariantId price:(ATTNPrice *)price {
  if (self = [super init]) {
    self->_productId = productId;
    self->_productVariantId = productVariantId;
    self->_price = price;
    self->_quantity = 1;
  }

  return self;
}

@end

NS_ASSUME_NONNULL_END
