//
//  ATTNSDKTest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 11/30/22.
//

#import <XCTest/XCTest.h>
#import "ATTNSDK.h"
#import "ATTNAPI.h"
#import "ATTNUserIdentity.h"

@interface ATTNSDK (Testing)

- (id)initWithDomain:(NSString *)domain mode:(NSString *)mode userIdentity:(ATTNUserIdentity *)userIdentity api:(ATTNAPI *) api;

@end

@interface ATTNSDKTest : XCTestCase

@end

@implementation ATTNSDKTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    ATTNUserIdentity* identity = [[ATTNUserIdentity alloc] init];
    ATTNAPI* api = [[ATTNAPI alloc] init];
    ATTNSDK* sdk = [[ATTNSDK alloc] initWithDomain:@"domainValue" mode:@"Production" userIdentity:identity api:api];
    
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

/*
 
 // TODO here are the public methods. Add test cases for them
 
 
 - (id)initWithDomain:(NSString *)domain;
 
 // init with empty domain, throws
 // init with good domain, succeeds

 - (id)initWithDomain:(NSString *)domain mode:(NSString *)mode;
 
 // init with empty domain, throws
 // init with good domain and empty mode, throws
 // init with good domain and good mode, succeeds

 - (void)identify: (NSObject *)userIdentifiers;
 
 // sets userIdentifiers

 - (void)trigger:(UIView *)theView;
 
 // the URL passed to the view/webview is correct

 - (void)clearUser;
 
 // identify has been called, resets the userIdentifiers
 // identify has not been called, no-op
 */

@end
