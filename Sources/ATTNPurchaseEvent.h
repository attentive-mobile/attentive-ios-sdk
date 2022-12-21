//
//  ATTNPurchaseEvent.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/7/22.
//

#import <Foundation/Foundation.h>
#import "ATTNEvent.h"

NS_ASSUME_NONNULL_BEGIN

@class ATTNOrder;
@class ATTNItem;
@class ATTNCart;

@interface ATTNPurchaseEvent : NSObject<ATTNEvent>

@property (readonly) NSArray<ATTNItem*>* items;
@property (readonly) ATTNOrder* order;
@property (nullable) ATTNCart* cart;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithItems:(NSArray<ATTNItem*>*)items order:(ATTNOrder*)order;

@end

NS_ASSUME_NONNULL_END
