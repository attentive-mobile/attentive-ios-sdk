//
//  ATTNAPITest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 11/28/22.
//

#import <XCTest/XCTest.h>
#import "ATTNAPI.h"

@interface ATTNAPITest : XCTestCase

@end

@interface ATTNAPI (Testing)

- (void)getGeoAdjustedDomain:(NSString *)domain completionHandler:(void (^)(NSString* _Nullable, NSError* _Nullable))completionHandler;

- (NSString*)constructUserIdentityUrl:(ATTNUserIdentity *)userIdentity domain:(NSString *)domain;

@end

@implementation ATTNAPITest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testConstructUserIdentityUrl {
    ATTNAPI* api = [[ATTNAPI alloc] init];
    ATTNUserIdentity* userIdentity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"some-client-id", IDENTIFIER_TYPE_EMAIL: @"some-email@email.com"}];
    
    [api constructUserIdentityUrl:userIdentity domain:@"some-domain"];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
