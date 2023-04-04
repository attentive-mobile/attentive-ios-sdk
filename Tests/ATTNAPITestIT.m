//
//  ATTNAPITestIT.m
//  attentive-ios-sdk Tests
//
//  Created by Olivia Kim on 3/7/23.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "ATTNAPI.h"
#import "ATTNTestEventUtils.h"


static NSString* const TEST_DOMAIN = @"mobileapps";
// Update this accordingly when running on VPN
static NSString* const TEST_GEO_ADJUSTED_DOMAIN = @"mobileapps";
static int EVENT_SEND_TIMEOUT_SEC = 6;


@interface ATTNAPITestIT : XCTestCase
@end


@implementation ATTNAPITestIT {
  ATTNAPI* api;
  ATTNUserIdentity* userIdentity;
}

- (void)setUp {
  api = [[ATTNAPI alloc] initWithDomain:TEST_DOMAIN];
  userIdentity = [[ATTNTestEventUtils class] buildUserIdentity];
}

- (void)testSendUserIdentity_validIdentifiers_sendsUserIdentifierCollectedEvent {
  // Arrange
  XCTestExpectation* eventTaskExpectation = [self expectationWithDescription:@"sendEventTask"];
  __block NSURLResponse* urlResponse;
  __block NSURL* eventUrl;


  // Act
  [api sendUserIdentity:userIdentity
               callback:^void(NSData* data, NSURL* url, NSURLResponse* response, NSError* error) {
                 if ([url.absoluteString containsString:@"t=idn"]) {
                   urlResponse = response;
                   eventUrl = url;
                   [eventTaskExpectation fulfill];
                 }
               }];
  [self waitForExpectationsWithTimeout:EVENT_SEND_TIMEOUT_SEC handler:nil];


  // Assert
  NSHTTPURLResponse* response = (NSHTTPURLResponse*)urlResponse;
  XCTAssertEqual(200, [response statusCode]);

  NSDictionary<NSString*, NSString*>* queryItems = [[ATTNTestEventUtils class] getQueryItemsFromUrl:eventUrl];
  NSString* queryItemsString = queryItems[@"m"];
  NSDictionary* metadata = [NSJSONSerialization JSONObjectWithData:[queryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

  [[ATTNTestEventUtils class] verifyCommonQueryItems:queryItems
                                        userIdentity:userIdentity
                                   geoAdjustedDomain:TEST_GEO_ADJUSTED_DOMAIN
                                           eventType:@"idn"
                                            metadata:metadata];

  XCTAssertEqualObjects(@"[{\"vendor\":\"2\",\"id\":\"someClientUserId\"},{\"vendor\":\"1\",\"id\":\"someKlaviyoId\"},{\"vendor\":\"0\",\"id\":\"someShopifyId\"},{\"vendor\":\"6\",\"id\":\"customIdValue\",\"name\":\"customId\"}]", queryItems[@"evs"]);
  XCTAssertEqualObjects(@"idn", queryItems[@"t"]);
}

- (void)testSendEvent_validPurchaseEvent_sendsPurchaseAndOrderConfirmedEvents {
  // Arrange
  ATTNPurchaseEvent* purchase = [[ATTNTestEventUtils class] buildPurchase];

  XCTestExpectation* purchaseTaskExpectation = [self expectationWithDescription:@"purchaseTask"];
  __block NSURLResponse* purchaseUrlResponse;
  __block NSURL* purchaseUrl;

  XCTestExpectation* ocTaskExpectation = [self expectationWithDescription:@"ocTask"];
  __block NSURLResponse* ocUrlResponse;
  __block NSURL* ocUrl;


  // Act
  [api sendEvent:purchase
      userIdentity:userIdentity
          callback:^void(NSData* data, NSURL* url, NSURLResponse* response, NSError* error) {
            if ([url.absoluteString containsString:@"t=p"]) {
              purchaseUrlResponse = response;
              purchaseUrl = url;
              [purchaseTaskExpectation fulfill];
            } else {
              ocUrlResponse = response;
              ocUrl = url;
              [ocTaskExpectation fulfill];
            }
          }];
  [self waitForExpectationsWithTimeout:EVENT_SEND_TIMEOUT_SEC handler:nil];


  // Assert

  // Purchase Event
  NSHTTPURLResponse* purchaseResponse = (NSHTTPURLResponse*)purchaseUrlResponse;
  XCTAssertEqual(200, [purchaseResponse statusCode]);

  NSDictionary<NSString*, NSString*>* purchaseQueryItems = [[ATTNTestEventUtils class] getQueryItemsFromUrl:purchaseUrl];
  NSString* purchaseQueryItemsString = purchaseQueryItems[@"m"];
  NSDictionary* purchaseMetadata = [NSJSONSerialization JSONObjectWithData:[purchaseQueryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

  [[ATTNTestEventUtils class] verifyCommonQueryItems:purchaseQueryItems
                                        userIdentity:userIdentity
                                   geoAdjustedDomain:TEST_GEO_ADJUSTED_DOMAIN
                                           eventType:@"p"
                                            metadata:purchaseMetadata];

  XCTAssertEqualObjects(purchase.items[0].productId, purchaseMetadata[@"productId"]);
  XCTAssertEqualObjects(purchase.items[0].productVariantId, purchaseMetadata[@"subProductId"]);
  XCTAssertEqualObjects(purchase.items[0].price.price, [[NSDecimalNumber alloc] initWithString:purchaseMetadata[@"price"]]);
  XCTAssertEqualObjects(purchase.items[0].price.currency, purchaseMetadata[@"currency"]);
  XCTAssertEqualObjects(purchase.items[0].category, purchaseMetadata[@"category"]);
  XCTAssertEqualObjects(purchase.items[0].productImage, purchaseMetadata[@"image"]);
  XCTAssertEqualObjects(purchase.items[0].name, purchaseMetadata[@"name"]);

  NSString* quantity = [NSString stringWithFormat:@"%d", purchase.items[0].quantity];
  XCTAssertEqualObjects(quantity, purchaseMetadata[@"quantity"]);
  XCTAssertEqualObjects(purchase.order.orderId, purchaseMetadata[@"orderId"]);
  XCTAssertEqualObjects(purchase.cart.cartId, purchaseMetadata[@"cartId"]);
  XCTAssertEqualObjects(purchase.cart.cartCoupon, purchaseMetadata[@"cartCoupon"]);


  // Order Confirmed Event
  NSHTTPURLResponse* ocResponse = (NSHTTPURLResponse*)ocUrlResponse;
  XCTAssertEqual(200, [ocResponse statusCode]);

  NSDictionary<NSString*, NSString*>* ocQueryItems = [[ATTNTestEventUtils class] getQueryItemsFromUrl:ocUrl];
  NSDictionary* ocMetadata = [[ATTNTestEventUtils class] getMetadataFromUrl:ocUrl];
  NSArray<NSDictionary*>* products = [NSJSONSerialization JSONObjectWithData:[ocMetadata[@"products"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
  XCTAssertEqual(1, products.count);

  [[ATTNTestEventUtils class] verifyCommonQueryItems:ocQueryItems
                                        userIdentity:userIdentity
                                   geoAdjustedDomain:TEST_GEO_ADJUSTED_DOMAIN
                                           eventType:@"oc"
                                            metadata:ocMetadata];

  [[ATTNTestEventUtils class] verifyProductFromItem:purchase.items[0] product:products[0]];

  XCTAssertEqualObjects(purchase.order.orderId, ocMetadata[@"orderId"]);
  XCTAssertEqualObjects(@"15.99", ocMetadata[@"cartTotal"]);
  XCTAssertEqualObjects(purchase.items[0].price.currency, ocMetadata[@"currency"]);
}

- (void)testSendEvent_validAddToCartEvent_sendsAddToCartEvent {
  // Arrange
  ATTNAddToCartEvent* addToCart = [[ATTNTestEventUtils class] buildAddToCart];

  XCTestExpectation* eventTaskExpectation = [self expectationWithDescription:@"sendEventTask"];
  __block NSURLResponse* urlResponse;
  __block NSURL* eventUrl;


  // Act
  [api sendEvent:addToCart
      userIdentity:userIdentity
          callback:^void(NSData* data, NSURL* url, NSURLResponse* response, NSError* error) {
            if ([url.absoluteString containsString:@"t=c"]) {
              urlResponse = response;
              eventUrl = url;
              [eventTaskExpectation fulfill];
            }
          }];
  [self waitForExpectationsWithTimeout:EVENT_SEND_TIMEOUT_SEC handler:nil];


  // Assert
  NSHTTPURLResponse* response = (NSHTTPURLResponse*)urlResponse;
  XCTAssertEqual(200, [response statusCode]);

  NSDictionary<NSString*, NSString*>* queryItems = [[ATTNTestEventUtils class] getQueryItemsFromUrl:eventUrl];
  NSString* queryItemsString = queryItems[@"m"];
  NSDictionary* metadata = [NSJSONSerialization JSONObjectWithData:[queryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

  [[ATTNTestEventUtils class] verifyCommonQueryItems:queryItems
                                        userIdentity:userIdentity
                                   geoAdjustedDomain:TEST_GEO_ADJUSTED_DOMAIN
                                           eventType:@"c"
                                            metadata:metadata];

  XCTAssertEqualObjects(addToCart.items[0].productId, metadata[@"productId"]);
  XCTAssertEqualObjects(addToCart.items[0].productVariantId, metadata[@"subProductId"]);
  XCTAssertEqualObjects(addToCart.items[0].price.price, [[NSDecimalNumber alloc] initWithString:metadata[@"price"]]);
  XCTAssertEqualObjects(addToCart.items[0].price.currency, metadata[@"currency"]);
  XCTAssertEqualObjects(addToCart.items[0].category, metadata[@"category"]);
  XCTAssertEqualObjects(addToCart.items[0].productImage, metadata[@"image"]);
  XCTAssertEqualObjects(addToCart.items[0].name, metadata[@"name"]);
  NSString* quantity = [NSString stringWithFormat:@"%d", addToCart.items[0].quantity];
  XCTAssertEqualObjects(quantity, metadata[@"quantity"]);
}

- (void)testSendEvent_validProductViewEvent_sendsProductViewEvent {
  // Arrange
  ATTNProductViewEvent* productView = [[ATTNTestEventUtils class] buildProductView];

  XCTestExpectation* eventTaskExpectation = [self expectationWithDescription:@"sendEventTask"];
  __block NSURLResponse* urlResponse;
  __block NSURL* eventUrl;


  // Act
  [api sendEvent:productView
      userIdentity:userIdentity
          callback:^void(NSData* data, NSURL* url, NSURLResponse* response, NSError* error) {
            if ([url.absoluteString containsString:@"t=d"]) {
              urlResponse = response;
              eventUrl = url;
              [eventTaskExpectation fulfill];
            }
          }];
  [self waitForExpectationsWithTimeout:EVENT_SEND_TIMEOUT_SEC handler:nil];


  // Assert
  NSHTTPURLResponse* response = (NSHTTPURLResponse*)urlResponse;
  XCTAssertEqual(200, [response statusCode]);

  NSDictionary<NSString*, NSString*>* queryItems = [[ATTNTestEventUtils class] getQueryItemsFromUrl:eventUrl];
  NSString* queryItemsString = queryItems[@"m"];
  NSDictionary* metadata = [NSJSONSerialization JSONObjectWithData:[queryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

  [[ATTNTestEventUtils class] verifyCommonQueryItems:queryItems
                                        userIdentity:userIdentity
                                   geoAdjustedDomain:TEST_GEO_ADJUSTED_DOMAIN
                                           eventType:@"d"
                                            metadata:metadata];

  XCTAssertEqualObjects(productView.items[0].productId, metadata[@"productId"]);
  XCTAssertEqualObjects(productView.items[0].productVariantId, metadata[@"subProductId"]);
  XCTAssertEqualObjects(productView.items[0].price.price, [[NSDecimalNumber alloc] initWithString:metadata[@"price"]]);
  XCTAssertEqualObjects(productView.items[0].price.currency, metadata[@"currency"]);
  XCTAssertEqualObjects(productView.items[0].category, metadata[@"category"]);
  XCTAssertEqualObjects(productView.items[0].productImage, metadata[@"image"]);
  XCTAssertEqualObjects(productView.items[0].name, metadata[@"name"]);
  NSString* quantity = [NSString stringWithFormat:@"%d", productView.items[0].quantity];
  XCTAssertEqualObjects(quantity, metadata[@"quantity"]);
}

- (void)testSendEvent_validCustomEvent_sendsCustomEvent {
  // Arrange
  ATTNCustomEvent* customEvent = [[ATTNTestEventUtils class] buildCustomEvent];

  XCTestExpectation* eventTaskExpectation = [self expectationWithDescription:@"sendEventTask"];
  __block NSURLResponse* urlResponse;
  __block NSURL* eventUrl;


  // Act
  [api sendEvent:customEvent
      userIdentity:userIdentity
          callback:^void(NSData* data, NSURL* url, NSURLResponse* response, NSError* error) {
            if ([url.absoluteString containsString:@"t=ce"]) {
              urlResponse = response;
              eventUrl = url;
              [eventTaskExpectation fulfill];
            }
          }];
  [self waitForExpectationsWithTimeout:EVENT_SEND_TIMEOUT_SEC handler:nil];


  // Assert
  NSHTTPURLResponse* response = (NSHTTPURLResponse*)urlResponse;
  XCTAssertEqual(200, [response statusCode]);

  NSDictionary<NSString*, NSString*>* queryItems = [[ATTNTestEventUtils class] getQueryItemsFromUrl:eventUrl];
  NSString* queryItemsString = queryItems[@"m"];
  NSDictionary* metadata = [NSJSONSerialization JSONObjectWithData:[queryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

  [[ATTNTestEventUtils class] verifyCommonQueryItems:queryItems
                                        userIdentity:userIdentity
                                   geoAdjustedDomain:TEST_GEO_ADJUSTED_DOMAIN
                                           eventType:@"ce"
                                            metadata:metadata];

  XCTAssertEqualObjects(customEvent.type, metadata[@"type"]);
  XCTAssertEqualObjects(customEvent.properties, [NSJSONSerialization JSONObjectWithData:[metadata[@"properties"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]);
}

@end
