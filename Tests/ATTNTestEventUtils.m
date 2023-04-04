//
//  ATTNTestEventUtils.m
//  attentive-ios-sdk Tests
//
//  Created by Olivia Kim on 3/7/23.
//

#import "ATTNTestEventUtils.h"


@implementation ATTNTestEventUtils


+ (void)verifyCommonQueryItems:(NSDictionary<NSString*, NSString*>*)queryItems
                  userIdentity:(ATTNUserIdentity*)userIdentity
             geoAdjustedDomain:(NSString*)geoAdjustedDomain
                     eventType:(NSString*)eventType
                      metadata:(NSDictionary*)metadata {
  XCTAssertEqualObjects(@"modern", queryItems[@"tag"]);
  XCTAssertEqualObjects(@"mobile-app", queryItems[@"v"]);
  XCTAssertEqualObjects(@"0", queryItems[@"lt"]);
  XCTAssertEqualObjects(geoAdjustedDomain, queryItems[@"c"]);
  XCTAssertEqualObjects(eventType, queryItems[@"t"]);
  XCTAssertEqualObjects(userIdentity.visitorId, queryItems[@"u"]);

  XCTAssertEqualObjects(userIdentity.identifiers[IDENTIFIER_TYPE_PHONE], metadata[@"phone"]);
  XCTAssertEqualObjects(userIdentity.identifiers[IDENTIFIER_TYPE_EMAIL], metadata[@"email"]);
  XCTAssertEqualObjects(@"msdk", metadata[@"source"]);
}

+ (void)verifyProductFromItem:(ATTNItem*)item product:(NSDictionary*)product {
  XCTAssertEqualObjects(item.productId, product[@"productId"]);
  XCTAssertEqualObjects(item.productVariantId, product[@"subProductId"]);
  XCTAssertEqualObjects(item.price.price, [[NSDecimalNumber alloc] initWithString:product[@"price"]]);
  XCTAssertEqualObjects(item.price.currency, product[@"currency"]);
  XCTAssertEqualObjects(item.category, product[@"category"]);
  XCTAssertEqualObjects(item.productImage, product[@"image"]);
  XCTAssertEqualObjects(item.name, product[@"name"]);
}

+ (NSDictionary*)getMetadataFromUrl:(NSURL*)url {
  NSDictionary<NSString*, NSString*>* queryItems = [[self class] getQueryItemsFromUrl:url];
  NSString* queryItemsString = queryItems[@"m"];
  return [NSJSONSerialization JSONObjectWithData:[queryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

+ (NSDictionary<NSString*, NSString*>*)getQueryItemsFromUrl:(NSURL*)url {
  NSArray<NSURLQueryItem*>* queryItems = [[NSURLComponents alloc] initWithString:url.absoluteString].queryItems;
  NSMutableDictionary* queryItemDict = [[NSMutableDictionary alloc] init];
  for (NSURLQueryItem* item in queryItems) {
    queryItemDict[item.name] = item.value;
  }

  return queryItemDict;
}

+ (ATTNPurchaseEvent*)buildPurchase {
  ATTNItem* item = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];
  item.category = @"someCategory";
  item.productImage = @"someImage";
  item.name = @"someName";
  ATTNOrder* order = [[ATTNOrder alloc] initWithOrderId:@"778899"];
  ATTNCart* cart = [[ATTNCart alloc] init];
  cart.cartId = @"789123";
  cart.cartCoupon = @"someCoupon";
  ATTNPurchaseEvent* purchaseEvent = [[ATTNPurchaseEvent alloc] initWithItems:@[ item ] order:order];
  purchaseEvent.cart = cart;
  return purchaseEvent;
}

+ (ATTNAddToCartEvent*)buildAddToCart {
  ATTNItem* item = [self buildItem];
  ATTNAddToCartEvent* event = [[ATTNAddToCartEvent alloc] initWithItems:@[ item ]];
  return event;
}

+ (ATTNProductViewEvent*)buildProductView {
  ATTNItem* item = [self buildItem];
  ATTNProductViewEvent* event = [[ATTNProductViewEvent alloc] initWithItems:@[ item ]];
  return event;
}

+ (ATTNItem*)buildItem {
  ATTNItem* item = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];
  item.category = @"someCategory";
  item.productImage = @"someImage";
  item.name = @"someName";
  return item;
}

+ (ATTNPurchaseEvent*)buildPurchaseWithTwoItems {
  ATTNItem* item1 = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];
  item1.category = @"someCategory";
  item1.productImage = @"someImage";
  item1.name = @"someName";
  ATTNItem* item2 = [[ATTNItem alloc] initWithProductId:@"2222" productVariantId:@"555552" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"20.00"] currency:@"USD"]];
  item2.category = @"someCategory2";
  item2.productImage = @"someImage2";
  item2.name = @"someName2";
  ATTNOrder* order = [[ATTNOrder alloc] initWithOrderId:@"778899"];
  ATTNCart* cart = [[ATTNCart alloc] init];
  cart.cartId = @"789123";
  cart.cartCoupon = @"someCoupon";
  ATTNPurchaseEvent* purchaseEvent = [[ATTNPurchaseEvent alloc] initWithItems:@[ item1, item2 ] order:order];
  purchaseEvent.cart = cart;
  return purchaseEvent;
}

+ (ATTNUserIdentity*)buildUserIdentity {
  return [[ATTNUserIdentity alloc] initWithIdentifiers:@{
    IDENTIFIER_TYPE_PHONE : @"+14156667777",
    IDENTIFIER_TYPE_EMAIL : @"someEmail@email.com",
    IDENTIFIER_TYPE_CLIENT_USER_ID : @"someClientUserId",
    IDENTIFIER_TYPE_SHOPIFY_ID : @"someShopifyId",
    IDENTIFIER_TYPE_KLAVIYO_ID : @"someKlaviyoId",
    IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS : @{@"customId" : @"customIdValue"}
  }];
}

+ (ATTNInfoEvent*)buildInfoEvent {
  return [[ATTNInfoEvent alloc] init];
}

+ (ATTNCustomEvent*)buildCustomEvent {
  return [[ATTNCustomEvent alloc] initWithType:@"Concert Viewed" properties:@{@"band" : @"The Beatles"}];
}

@end
