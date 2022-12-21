//
//  ATTNAPITest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 11/28/22.
//

#import <XCTest/XCTest.h>
#import "ATTNAPI.h"
#import "ATTNUserIdentity.h"
#import "ATTNPurchaseEvent.h"
#import "ATTNEvent.h"
#import "ATTNItem.h"
#import "ATTNOrder.h"
#import "ATTNPrice.h"
#import "ATTNCart.h"

static NSString* const TEST_DOMAIN = @"some-domain";

@interface ATTNAPI (Testing)

- (instancetype)initWithDomain:domain urlSession:(NSURLSession*)urlSession;

- (void)getGeoAdjustedDomain:(NSString *)domain completionHandler:(void (^)(NSString* _Nullable, NSError* _Nullable))completionHandler;

- (NSURL*)constructUserIdentityUrl:(ATTNUserIdentity *)userIdentity domain:(NSString *)domain;

@end

@interface NSURLSessionDataTaskMock : NSURLSessionDataTask

- (id)initWithHandler:(void (NS_SWIFT_SENDABLE ^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

- (void)resume;

@end

@implementation NSURLSessionDataTaskMock {
    void (^_completionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
}

- (id)initWithHandler:(void (NS_SWIFT_SENDABLE ^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    self = [super init];
    _completionHandler = completionHandler;
    return self;
}

- (void)resume {
    // do nothing
    _completionHandler(nil, nil, nil);
}

@end

@interface NSURLSessionMock : NSURLSession

@property bool didCallDtag;
@property bool didCallEventsApi;
@property NSMutableArray<NSURL*>* urlCalls;

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (NS_SWIFT_SENDABLE ^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

@implementation NSURLSessionMock

- (instancetype)init {
    if (self = [super init]) {
        _urlCalls = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (NS_SWIFT_SENDABLE ^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    [_urlCalls addObject:url];
    
    if ([[url absoluteString] containsString:@"cdn.attn.tv"]) {
        _didCallDtag = true;
        return [[NSURLSessionDataTaskMock alloc] initWithHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
            completionHandler([@"window.__attentive_domain='some-domain.attn.tv'" dataUsingEncoding:NSUTF8StringEncoding], [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:nil headerFields:nil], nil);
        }];
    }
    
    if ([[url absoluteString] containsString:@"events.attentivemobile.com"]) {
        _didCallEventsApi = true;
        return [[NSURLSessionDataTaskMock alloc] initWithHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
            completionHandler([[NSData alloc] init], [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:nil headerFields:nil], nil);
        }];
    }
    
    // should not get here
    assert(false);
}

@end

@interface ATTNAPITest : XCTestCase

@end

@implementation ATTNAPITest

- (void)testSendUserIdentity_validIdentifiers_callsEndpoints {
    NSURLSessionMock* sessionMock = [[NSURLSessionMock alloc] init];
    ATTNAPI* api = [[ATTNAPI alloc] initWithDomain:TEST_DOMAIN urlSession:sessionMock];
    
    ATTNUserIdentity* userIdentity = [self buildUserIdentity];
    [api sendUserIdentity:userIdentity];
    
    XCTAssertTrue(sessionMock.didCallDtag);
    XCTAssertTrue(sessionMock.didCallEventsApi);
}

- (void)testSendEvent_validEvent_callsEventEndpoint {
    // Arrange
    NSURLSessionMock* sessionMock = [[NSURLSessionMock alloc] init];
    ATTNAPI* api = [[ATTNAPI alloc] initWithDomain:TEST_DOMAIN urlSession:sessionMock];
    ATTNPurchaseEvent* purchase = [self buildPurchase];
    ATTNUserIdentity* userIdentity = [self buildUserIdentity];
    
    // Act
    [api sendEvent:purchase userIdentity:userIdentity];
    
    // Assert
    XCTAssertTrue(sessionMock.didCallEventsApi);
    XCTAssertEqual(3, sessionMock.urlCalls.count);
    NSURL* eventsUrl = sessionMock.urlCalls[1];
    NSDictionary* queryItems = [self getQueryItemsFromUrl:eventsUrl];
    XCTAssertEqualObjects(@"mobile-app", queryItems[@"v"]);
    XCTAssertEqualObjects(@"p", queryItems[@"t"]);
}

- (void)testSendEvent_validPurchaseEvent_urlContainsExpectedPurchaseMetadata {
    // Arrange
    NSURLSessionMock* sessionMock = [[NSURLSessionMock alloc] init];
    ATTNAPI* api = [[ATTNAPI alloc] initWithDomain:TEST_DOMAIN urlSession:sessionMock];
    ATTNPurchaseEvent* purchase = [self buildPurchase];
    ATTNUserIdentity* userIdentity = [self buildUserIdentity];
    
    // Act
    [api sendEvent:purchase userIdentity:userIdentity];
    
    // Assert
    XCTAssertTrue(sessionMock.didCallEventsApi);
    XCTAssertEqual(3, sessionMock.urlCalls.count);
    NSURL* purchaseUrl = sessionMock.urlCalls[1];
    NSDictionary<NSString*, NSString*>* queryItems = [self getQueryItemsFromUrl:purchaseUrl];
    NSString* queryItemsString = queryItems[@"m"];
    NSDictionary* metadata = [NSJSONSerialization JSONObjectWithData:[queryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    
    XCTAssertEqualObjects(purchase.items[0].productId, metadata[@"productId"]);
    XCTAssertEqualObjects(purchase.items[0].productVariantId, metadata[@"subProductId"]);
    XCTAssertEqualObjects(purchase.items[0].price.price, [[NSDecimalNumber alloc] initWithString: metadata[@"price"]]);
    XCTAssertEqualObjects(purchase.items[0].price.currency, metadata[@"currency"]);
    XCTAssertEqualObjects(purchase.items[0].category, metadata[@"category"]);
    XCTAssertEqualObjects(purchase.items[0].productImage, metadata[@"image"]);
    XCTAssertEqualObjects(purchase.items[0].name, metadata[@"name"]);
    XCTAssertEqualObjects(purchase.order.orderId, metadata[@"orderId"]);
    XCTAssertEqualObjects(purchase.cart.cartId, metadata[@"cartId"]);
    XCTAssertEqualObjects(purchase.cart.cartCoupon, metadata[@"cartCoupon"]);
}

- (void)testSendEvent_validPurchaseEventWithTwoItems_urlContainsExpectedOrderConfirmedMetadata {
    // Arrange
    NSURLSessionMock* sessionMock = [[NSURLSessionMock alloc] init];
    ATTNAPI* api = [[ATTNAPI alloc] initWithDomain:TEST_DOMAIN urlSession:sessionMock];
    ATTNPurchaseEvent* purchase = [self buildPurchaseWithTwoItems];
    ATTNUserIdentity* userIdentity = [self buildUserIdentity];
    
    // Act
    [api sendEvent:purchase userIdentity:userIdentity];
    
    // Assert
    XCTAssertTrue(sessionMock.didCallEventsApi);
    XCTAssertEqual(4, sessionMock.urlCalls.count);
    NSURL* orderConfirmedUrl = nil;
    for (NSURL* url in sessionMock.urlCalls) {
        if ([url.absoluteString containsString:@"t=oc"]){
            orderConfirmedUrl = url;
        }
    }
    XCTAssertNotNil(orderConfirmedUrl);
    
    NSDictionary* ocMetadata = [self getMetadataFromUrl:orderConfirmedUrl];
    NSArray<NSDictionary*>* products = [NSJSONSerialization JSONObjectWithData:[ocMetadata[@"products"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    XCTAssertEqual(2, products.count);
    
    [self verifyProductFromItem:purchase.items[0] product:products[0]];
    [self verifyProductFromItem:purchase.items[1] product:products[1]];

    XCTAssertEqualObjects(purchase.order.orderId, ocMetadata[@"orderId"]);
    XCTAssertEqualObjects(@"35.99", ocMetadata[@"cartTotal"]);
    XCTAssertEqualObjects(purchase.items[0].price.currency, ocMetadata[@"currency"]);
}

- (void)verifyProductFromItem:(ATTNItem*)item product:(NSDictionary*)product {
    XCTAssertEqualObjects(item.productId, product[@"productId"]);
    XCTAssertEqualObjects(item.productVariantId, product[@"subProductId"]);
    XCTAssertEqualObjects(item.price.price, [[NSDecimalNumber alloc] initWithString: product[@"price"]]);
    XCTAssertEqualObjects(item.price.currency, product[@"currency"]);
    XCTAssertEqualObjects(item.category, product[@"category"]);
    XCTAssertEqualObjects(item.productImage, product[@"image"]);
    XCTAssertEqualObjects(item.name, product[@"name"]);
}

- (void)testSendEvent_purchaseEventWithTwoItems_threeRequestsAreSent {
    // Arrange
    NSURLSessionMock* sessionMock = [[NSURLSessionMock alloc] init];
    ATTNAPI* api = [[ATTNAPI alloc] initWithDomain:TEST_DOMAIN urlSession:sessionMock];
    ATTNPurchaseEvent* purchase = [self buildPurchaseWithTwoItems];
    ATTNUserIdentity* userIdentity = [self buildUserIdentity];
    
    // Act
    [api sendEvent:purchase userIdentity:userIdentity];
    
    // Assert
    XCTAssertTrue(sessionMock.didCallEventsApi);
    XCTAssertEqual(4, sessionMock.urlCalls.count);
    
    // check the first item was converted to an event call
    NSDictionary* metadata = [self getMetadataFromUrl:sessionMock.urlCalls[1]];
    XCTAssertEqualObjects(purchase.items[0].productId, metadata[@"productId"]);
    NSDictionary* queryItems = [self getQueryItemsFromUrl:sessionMock.urlCalls[1]];
    XCTAssertEqualObjects(@"p", queryItems[@"t"]);
    
    // check the second item was converted to an event call
    NSDictionary* metadata2 = [self getMetadataFromUrl:sessionMock.urlCalls[2]];
    XCTAssertEqualObjects(purchase.items[1].productId, metadata2[@"productId"]);
    NSDictionary* queryItems2 = [self getQueryItemsFromUrl:sessionMock.urlCalls[2]];
    XCTAssertEqualObjects(@"p", queryItems2[@"t"]);
    
    // check an OrderConfirmed was created
    NSDictionary* metadata3 = [self getMetadataFromUrl:sessionMock.urlCalls[3]];
    XCTAssertEqualObjects(purchase.order.orderId, metadata3[@"orderId"]);
    NSDictionary* queryItems3 = [self getQueryItemsFromUrl:sessionMock.urlCalls[3]];
    XCTAssertEqualObjects(@"oc", queryItems3[@"t"]);
}

- (NSDictionary*)getMetadataFromUrl:(NSURL*)url {
    NSDictionary<NSString*, NSString*>* queryItems = [self getQueryItemsFromUrl:url];
    NSString* queryItemsString = queryItems[@"m"];
    return [NSJSONSerialization JSONObjectWithData:[queryItemsString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

- (NSDictionary<NSString*, NSString*>*)getQueryItemsFromUrl:(NSURL*)url {
    NSArray<NSURLQueryItem*>* queryItems = [[NSURLComponents alloc] initWithString:url.absoluteString].queryItems;
    NSMutableDictionary* queryItemDict = [[NSMutableDictionary alloc] init];
    for (NSURLQueryItem* item in queryItems) {
        queryItemDict[item.name] = item.value;
    }
    
    return queryItemDict;
}

- (ATTNPurchaseEvent*)buildPurchase {
    ATTNItem* item = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];
    item.category = @"someCategory";
    item.productImage = @"someImage";
    item.name = @"someName";
    ATTNOrder* order = [[ATTNOrder alloc] initWithOrderId:@"778899"];
    ATTNCart* cart = [[ATTNCart alloc] init];
    cart.cartId = @"789123";
    cart.cartCoupon = @"someCoupon";
    ATTNPurchaseEvent* purchaseEvent = [[ATTNPurchaseEvent alloc] initWithItems:@[item] order:order];
    purchaseEvent.cart = cart;
    return purchaseEvent;
}

- (ATTNPurchaseEvent*)buildPurchaseWithTwoItems {
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
    ATTNPurchaseEvent* purchaseEvent = [[ATTNPurchaseEvent alloc] initWithItems:@[item1, item2] order:order];
    purchaseEvent.cart = cart;
    return purchaseEvent;
}

- (ATTNUserIdentity*)buildUserIdentity {
    return [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"some-client-id", IDENTIFIER_TYPE_EMAIL: @"some-email@email.com"}];
}

@end
