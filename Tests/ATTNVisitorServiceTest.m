//
//  ATTNVisitorServiceTest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 11/30/22.
//

#import <XCTest/XCTest.h>
#import "ATTNVisitorService.h"

@interface ATTNVisitorServiceTest : XCTestCase

@end

@implementation ATTNVisitorServiceTest {
  ATTNVisitorService* _visitorService;
}

- (void)setUp {
  _visitorService = [[ATTNVisitorService alloc] init];
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGetVisitorId_returnedIdIsNotNilAndCorrectFormat {
  NSString* visitorId = [_visitorService getVisitorId];
  XCTAssertNotNil(visitorId);
  XCTAssertTrue([visitorId length] != 0);
}

- (void)testGetVisitorId_callGetVisitorIdTwice_returnsSameId {
  NSString* visitorId = [_visitorService getVisitorId];
  XCTAssertNotNil(visitorId);
  XCTAssertTrue([visitorId length] != 0);

  XCTAssertTrue([visitorId isEqualToString:[_visitorService getVisitorId]]);
}

- (void)testCreateNewVisitorId_call_returnsNewId {
  NSString* oldVisitorId = [_visitorService getVisitorId];
  NSString* newVisitorId = [_visitorService createNewVisitorId];

  XCTAssertFalse([oldVisitorId isEqualToString:newVisitorId]);
}

- (void)testCreateNewVisitorId_noVisitorIdHasBeenRetrievedYet_returnsId {
  NSString* newVisitorId = [_visitorService createNewVisitorId];
  XCTAssertNotNil(newVisitorId);
}

- (void)testCreateNewVisitorId_createThenGet_sameId {
  NSString* newVisitorId = [_visitorService createNewVisitorId];
  XCTAssertTrue([newVisitorId isEqualToString:[_visitorService getVisitorId]]);
}

@end
