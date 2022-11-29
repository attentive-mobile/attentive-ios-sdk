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

- (NSURL*)constructUserIdentityUrl:(ATTNUserIdentity *)userIdentity domain:(NSString *)domain;

@end

@implementation ATTNAPITest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testConstructUserIdentityUrl {
    ATTNAPI* api = [[ATTNAPI alloc] init];
    ATTNUserIdentity* userIdentity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"some-client-id", IDENTIFIER_TYPE_EMAIL: @"some-email@email.com"}];
    
    NSURL* url = [api constructUserIdentityUrl:userIdentity domain:@"some-domain"];
    XCTAssertNotNil(url);
}


@end
