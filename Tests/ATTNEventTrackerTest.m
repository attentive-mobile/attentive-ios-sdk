//
//  ATTNEventTrackerTest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 12/16/22.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "ATTNEventTracker.h"
#import "TestAssertionHandler.h"
#import "ATTNSDK.h"
#import "ATTNPurchaseEvent.h"
#import "ATTNOrder.h"
#import "ATTNAPI.h"

@interface ATTNEventTracker (Test)

- (id)initWithSdk:(ATTNSDK*)sdk;

@end

@interface ATTNEventTrackerTest : XCTestCase

@end

@interface ATTNSDK (Internal)

- (ATTNAPI*)getApi;

@end

@implementation ATTNEventTrackerTest

- (void)setUp {
}

- (void)tearDown {
}

- (void)testGetSharedInstance_notSetup_throws {
    // This method has multiple cases so that the order of the cases is always the same. If each case was in a separate test method we could not guarantee ordering.
    
    // **************
    // Case 1: verify that if getSharedInstance is called before setupWithSdk is called then an assertion is triggered
    // **************
    
    NSAssertionHandler* originalHandler = [NSAssertionHandler currentHandler];
    
    // add the test handler
    TestAssertionHandler* testHandler = [[TestAssertionHandler alloc] init];
    [[[NSThread currentThread] threadDictionary] setValue:testHandler
                                                     forKey:NSAssertionHandlerKey];

    XCTAssertFalse([testHandler wasAssertionThrown]);
    [ATTNEventTracker sharedInstance];
    XCTAssertTrue([testHandler wasAssertionThrown]);
    
    // reset the original handler
    [[[NSThread currentThread] threadDictionary] setValue:originalHandler
                                                     forKey:NSAssertionHandlerKey];
    // **************
    // CASE 2: verify that if setupWithSdk is called before getSharedInstance then no assertion is triggered
    // **************

    ATTNSDK* sdkMock = OCMClassMock([ATTNSDK class]);
    [ATTNEventTracker setupWithSdk:sdkMock];
    
    // Does not throw
    [ATTNEventTracker sharedInstance];
}

- (void)testRecordEvent_validEvent_callsApi {
    // Arrange
    ATTNSDK* sdkMock = OCMClassMock([ATTNSDK class]);
    ATTNAPI* apiMock = OCMClassMock([ATTNAPI class]);
    OCMStub([sdkMock getApi]).andReturn(apiMock);

    ATTNEventTracker* eventTracker = [[ATTNEventTracker alloc] initWithSdk:sdkMock];
    
    ATTNPurchaseEvent* purchase = [[ATTNPurchaseEvent alloc] initWithItems:[[NSArray alloc] init] order:[[ATTNOrder alloc] initWithOrderId:@"orderId"]];
    
    // Act
    // Does not throw
    [eventTracker recordEvent:purchase];
    
    // Assert
    OCMVerify([apiMock sendEvent:purchase userIdentity:[OCMArg isNil]]);
}

@end
