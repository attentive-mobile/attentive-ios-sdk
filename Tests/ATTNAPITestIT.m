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


@implementation ATTNAPITestIT

- (void)testSendEvent_validPurchaseEvent_urlContainsExpectedPurchaseMetadata {
    // Arrange
    ATTNAPI* api = [[ATTNAPI alloc] initWithDomain:TEST_DOMAIN];
    ATTNPurchaseEvent* purchase = [[ATTNTestEventUtils class] buildPurchase];
    ATTNUserIdentity* userIdentity = [[ATTNTestEventUtils class] buildUserIdentity];
    
    XCTestExpectation *purchaseTaskExpectation = [self expectationWithDescription:@"purchaseTask"];
    __block NSURLResponse* purchaseUrlResponse;
    __block NSURL* purchaseUrl;
    
    XCTestExpectation *ocTaskExpectation = [self expectationWithDescription:@"ocTask"];
    __block NSURLResponse* ocUrlResponse;
    __block NSURL* ocUrl;

    
    // Act
    [api sendEvent:purchase userIdentity:userIdentity callback:^ void (NSURL* url, NSURLResponse *response, NSError *error) {
        if ([url.absoluteString containsString:@"t=p"]){
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
    NSHTTPURLResponse *purchaseResponse = (NSHTTPURLResponse*) purchaseUrlResponse;
    XCTAssertEqual(200, [purchaseResponse statusCode]);
    
    NSDictionary<NSString*, NSString*>* purchaseQueryItems = [[ATTNTestEventUtils class] getQueryItemsFromUrl:purchaseUrl];
    NSString* purchaseQueryItemsString = purchaseQueryItems[@"m"];
    NSDictionary* purchaseMetadata = [NSJSONSerialization JSONObjectWithData:[purchaseQueryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    
    XCTAssertEqualObjects(purchase.items[0].productId, purchaseMetadata[@"productId"]);
    XCTAssertEqualObjects(purchase.items[0].productVariantId, purchaseMetadata[@"subProductId"]);
    XCTAssertEqualObjects(purchase.items[0].price.price, [[NSDecimalNumber alloc] initWithString: purchaseMetadata[@"price"]]);
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
    NSHTTPURLResponse *ocResponse = (NSHTTPURLResponse*) ocUrlResponse;
    XCTAssertEqual(200, [ocResponse statusCode]);
    
    NSDictionary<NSString*, NSString*>* ocQueryItems = [[ATTNTestEventUtils class] getQueryItemsFromUrl:ocUrl];
    NSDictionary* ocMetadata = [[ATTNTestEventUtils class] getMetadataFromUrl:ocUrl];
    NSArray<NSDictionary*>* products = [NSJSONSerialization JSONObjectWithData:[ocMetadata[@"products"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    XCTAssertEqual(1, products.count);
    
    [[ATTNTestEventUtils class] verifyProductFromItem:purchase.items[0] product:products[0]];

    XCTAssertEqualObjects(purchase.order.orderId, ocMetadata[@"orderId"]);
    XCTAssertEqualObjects(@"15.99", ocMetadata[@"cartTotal"]);
    XCTAssertEqualObjects(purchase.items[0].price.currency, ocMetadata[@"currency"]);
}

@end
