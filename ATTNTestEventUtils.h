//
//  ATTNTestEventUtils.h
//  attentive-ios-sdk
//
//  Created by Olivia Kim on 3/7/23.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "ATTNAPI.h"
#import "ATTNUserIdentity.h"
#import "ATTNPurchaseEvent.h"
#import "ATTNAddToCartEvent.h"
#import "ATTNProductViewEvent.h"
#import "ATTNEvent.h"
#import "ATTNItem.h"
#import "ATTNOrder.h"
#import "ATTNPrice.h"
#import "ATTNCart.h"
#import "ATTNInfoEvent.h"

#ifndef ATTNTestEventUtils_h
#define ATTNTestEventUtils_h


@interface ATTNTestEventUtils: NSObject

+ (void)verifyCommonQueryItems:(NSDictionary<NSString*, NSString*>*)queryItems
                  userIdentity:(ATTNUserIdentity *)userIdentity
             geoAdjustedDomain:(NSString *)geoAdjustedDomain
                     eventType:(NSString *)eventType
                      metadata:(NSDictionary *) metadata;

+ (void)verifyProductFromItem:(ATTNItem*)item product:(NSDictionary*)product;

+ (NSDictionary*)getMetadataFromUrl:(NSURL*)url;

+ (NSDictionary<NSString*, NSString*>*)getQueryItemsFromUrl:(NSURL*)url;

+ (ATTNPurchaseEvent*)buildPurchase;

+ (ATTNAddToCartEvent*)buildAddToCart;

+ (ATTNProductViewEvent*)buildProductView;

+ (ATTNItem*)buildItem;

+ (ATTNPurchaseEvent*)buildPurchaseWithTwoItems;

+ (ATTNUserIdentity*)buildUserIdentity;

+ (ATTNInfoEvent*)buildInfoEvent;

@end


#endif /* ATTNTestEventUtils_h */
