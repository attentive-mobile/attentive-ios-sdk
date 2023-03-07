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

#ifndef ATTNTestEventUtils_h
#define ATTNTestEventUtils_h


@interface ATTNTestEventUtils: NSObject

+ (void)verifyProductFromItem:(ATTNItem*)item product:(NSDictionary*)product;
+ (NSDictionary*)getMetadataFromUrl:(NSURL*)url;
+ (NSDictionary<NSString*, NSString*>*)getQueryItemsFromUrl:(NSURL*)url;
+ (ATTNPurchaseEvent*)buildPurchase;
+ (ATTNAddToCartEvent*)buildAddToCart;
+ (ATTNProductViewEvent*)buildProductView;
+ (ATTNItem*)buildItem;
+ (ATTNPurchaseEvent*)buildPurchaseWithTwoItems;
+ (ATTNUserIdentity*)buildUserIdentity;

@end


#endif /* ATTNTestEventUtils_h */
