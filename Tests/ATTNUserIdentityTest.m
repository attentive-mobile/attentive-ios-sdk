//
//  ATTNUserIdentityTest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 11/29/22.
//

#import <XCTest/XCTest.h>
#import "ATTNUserIdentity.h"

@interface ATTNUserIdentityTest : XCTestCase

@end

@implementation ATTNUserIdentityTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testInit_doesNotThrow {
    XCTAssertNoThrow([[ATTNUserIdentity alloc] init]);
}

- (void)testInitWithIdentifiers_emptyIdentifiers_succeeds {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{}];
    XCTAssertEqual(0, identity.identifiers.count);
}

- (void)testInitWithIdentifiers_validIdentifiers_succeeds {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"someValue"}];
    XCTAssertTrue([@"someValue" isEqualToString:identity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]]);
}

- (void)testInitWithIdentifiers_invalidIdentifiers_throws {
    XCTAssertThrows([[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: [[NSDictionary alloc] init]}]);
}

- (void)testMergeIdentifiers_noExistingIdentifiersAndMergeEmptyIdentifiers_identifiersAreEmpty {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] init];
    [identity mergeIdentifiers:@{}];
    
    XCTAssertEqual(0, identity.identifiers.count);
}

- (void)testMergeIdentifiers_noExistingIdentifiersAndMergeNonEmptyIdentifiers_identifiersAreMerged {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] init];
    [identity mergeIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"someValue"}];
    
    XCTAssertEqual(1, identity.identifiers.count);
}

- (void)testMergeIdentifiers_existingIdentifiersAndMergeEmptyIdentifiers_identifiersDidNotChange {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"someValue"}];
    [identity mergeIdentifiers:@{}];
    
    XCTAssertEqual(1, identity.identifiers.count);
    XCTAssertTrue([@"someValue" isEqualToString:identity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]]);
}

- (void)testMergeIdentifiers_existingIdentifiersAndMergeNewIdentifiers_identifiersUpdated {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"someValue", IDENTIFIER_TYPE_EMAIL: @"someEmail"}];
    [identity mergeIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"newValue", IDENTIFIER_TYPE_PHONE: @"somePhone"}];
    
    XCTAssertEqual(3, identity.identifiers.count);
    XCTAssertTrue([@"newValue" isEqualToString:identity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]]);
    XCTAssertTrue([@"somePhone" isEqualToString:identity.identifiers[IDENTIFIER_TYPE_PHONE]]);
    XCTAssertTrue([@"someEmail" isEqualToString:identity.identifiers[IDENTIFIER_TYPE_EMAIL]]);
}

- (void)testClearUser_noExistingIdentifiers_noop {
    XCTAssertNoThrow([[[ATTNUserIdentity alloc] init] clearUser]);
}

- (void)testClearUser_existingIdentifiers_clearsIdentifiers {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"someValue"}];
    [identity clearUser];
    
    XCTAssertEqual(0, identity.identifiers.count);
}

- (void)testClearUser_existingIdentifiersAndMergeAfterClearing_clearsIdentifiers {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"someValue"}];
    [identity clearUser];
    
    [identity mergeIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"someValue"}];
    XCTAssertEqual(1, identity.identifiers.count);
    XCTAssertTrue([@"someValue" isEqualToString:identity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]]);
}

@end
