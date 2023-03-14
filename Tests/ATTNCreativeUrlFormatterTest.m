//
//  ATTNCreativeUrlFormatterTest.m
//  attentive-ios-sdk
//
//  Created by Olivia Kim on 3/9/23.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "ATTNCreativeUrlFormatter.h"
#import "ATTNUserIdentity.h"
#import "ATTNTestEventUtils.h"


@interface ATTNCreativeUrlFormatterTest : XCTestCase

@end


@implementation ATTNCreativeUrlFormatterTest

static NSString* const TEST_DOMAIN = @"testDomain";


- (void)testBuildCompanyCreativeUrlForDomain_productionMode_buildsProdUrl {
    ATTNUserIdentity* userIdentity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{}];
    NSString* url = [[ATTNCreativeUrlFormatter class]
                     buildCompanyCreativeUrlForDomain:TEST_DOMAIN
                     mode:@"production"
                     userIdentity:userIdentity];
    
    NSString * expectedUrl = [NSString stringWithFormat:@"https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&vid=%@", userIdentity.visitorId];
    
    XCTAssertTrue([expectedUrl isEqualToString:url]);
}

- (void)testBuildCompanyCreativeUrlForDomain_productionMode_buildsDebugUrl {
    ATTNUserIdentity* userIdentity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{}];
    NSString* url = [[ATTNCreativeUrlFormatter class]
                     buildCompanyCreativeUrlForDomain:TEST_DOMAIN
                     mode:@"debug"
                     userIdentity:userIdentity];
    
    NSString * expectedUrl = [NSString stringWithFormat:@"https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&debug=matter-trip-grass-symbol&vid=%@", userIdentity.visitorId];
    
    XCTAssertTrue([expectedUrl isEqualToString:url]);
}

- (void)testBuildCompanyCreativeUrlForDomain_withUserIdentifiers_buildsUrlWithIdentifierQueryParams {
    ATTNUserIdentity* userIdentity = [[ATTNTestEventUtils class] buildUserIdentity];
    NSString* url = [[ATTNCreativeUrlFormatter class]
                     buildCompanyCreativeUrlForDomain:TEST_DOMAIN
                     mode:@"production"
                     userIdentity:userIdentity];
    
    NSString * expectedUrl = [NSString stringWithFormat:@"https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&vid=%@&cuid=someClientUserId&p=+14156667777&e=someEmail@email.com&kid=someKlaviyoId&sid=someKlaviyoId&cstm=%%7B%%22customId%%22:%%22customIdValue%%22%%7D", userIdentity.visitorId];
    
    XCTAssertTrue([expectedUrl isEqualToString:url]);
}

- (void)testBuildCompanyCreativeUrlForDomain_customIdentifiersCannotBeSerialized_doesNotThrow {
    NSException *exception = [NSException exceptionWithName:@"Test Exception"
                                                reason:@"Test Exception"
                                              userInfo:nil];
    NSError *error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain
                                                   code:NSPropertyListWriteInvalidError
                                               userInfo:nil];

    id classMock = OCMClassMock([NSJSONSerialization class]);
    OCMStub(ClassMethod([classMock dataWithJSONObject:OCMOCK_ANY
                                              options:0
                                                error:[OCMArg setTo:error]])).andThrow(exception);
    
    
    ATTNUserIdentity* userIdentity = [[ATTNTestEventUtils class] buildUserIdentity];
    NSString* url = [[ATTNCreativeUrlFormatter class]
                     buildCompanyCreativeUrlForDomain:TEST_DOMAIN
                     mode:@"production"
                     userIdentity:userIdentity];
    
    NSString * expectedUrl = [NSString stringWithFormat:@"https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&vid=%@&cuid=someClientUserId&p=+14156667777&e=someEmail@email.com&kid=someKlaviyoId&sid=someKlaviyoId&cstm=%%7B%%7D", userIdentity.visitorId];
    
    XCTAssertTrue([expectedUrl isEqualToString:url]);
}

@end

