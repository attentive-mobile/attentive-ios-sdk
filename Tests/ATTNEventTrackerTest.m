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

@interface ATTNEventTracker (Test)

+ (void)resetInstance;

@end

@interface ATTNEventTrackerTest : XCTestCase

@end

@implementation ATTNEventTrackerTest

- (void)setUp {
}

- (void)tearDown {
    [ATTNEventTracker resetInstance];
}


- (void)testGetSharedInstance_notSetup_throws {
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
}

- (void)testSetupWithSDK_validSdk_getSharedInstanceSucceeds {
    ATTNSDK* sdkMock = OCMClassMock([ATTNSDK class]);
    [ATTNEventTracker setupWithSdk:sdkMock];
    
    // Does not throw
    [ATTNEventTracker sharedInstance];
}

- (void)testRecordEvent_validEvent_callsApi {
    ATTNSDK* sdkMock = OCMClassMock([ATTNSDK class]);
    [ATTNEventTracker setupWithSdk:sdkMock];
    
    // Does not throw
    [ATTNEventTracker sharedInstance];
    
    ATTNPurchaseEvent* purchase = [[ATTNPurchaseEvent alloc] initWithItems:[[NSArray alloc] init] order:[[ATTNOrder alloc] initWithOrderId:@"orderId"]];
    
    // Does not throw
    [[ATTNEventTracker sharedInstance] recordEvent:purchase];
    
    // TODO validate it calls the API
}

@end
