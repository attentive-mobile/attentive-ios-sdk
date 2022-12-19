//
//  ATTNPurchaseEvent.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/7/22.
//

#ifndef ATTNPurchaseEvent_h
#define ATTNPurchaseEvent_h

#import <Foundation/Foundation.h>
#import "ATTNEvent.h"

@class ATTNOrder;
@class ATTNItem;
@class ATTNCart;

@interface ATTNPurchaseEvent : NSObject<ATTNEvent>

@property (readonly) NSArray<ATTNItem*>* items;
@property (readonly) ATTNOrder* order;
@property ATTNCart* cart;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithItems:(NSArray<ATTNItem*>*)items order:(ATTNOrder*)order;

@end

#endif /* ATTNPurchaseEvent_h */
