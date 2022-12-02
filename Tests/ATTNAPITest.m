//
//  ATTNAPITest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 11/28/22.
//

#import <XCTest/XCTest.h>
#import "ATTNAPI.h"
#import "ATTNUserIdentity.h"

@interface ATTNAPI (Testing)

- (NSURLSession*)session;

- (void)setSession:(NSURLSession*)session;

@end

@interface ATTNAPITest : XCTestCase

@end

@interface ATTNAPI (Testing)

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

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (NS_SWIFT_SENDABLE ^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

@implementation NSURLSessionMock

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (NS_SWIFT_SENDABLE ^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    if ([[url absoluteString] containsString:@"cdn.attn.tv"]) {
        _didCallDtag = true;
        return [[NSURLSessionDataTaskMock alloc] initWithHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
            completionHandler([@"window.__attentive_domain='fakedomain.attn.tv'" dataUsingEncoding:NSUTF8StringEncoding], [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:nil headerFields:nil], nil);
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


@implementation ATTNAPITest

- (void)testSendUserIdentity_validIdentifiers_callsEndpoints {
    ATTNAPI* api = [[ATTNAPI alloc] init];
    NSURLSessionMock* sessionMock = [[NSURLSessionMock alloc] init];
    api.session = sessionMock;
    
    ATTNUserIdentity* userIdentity = [[ATTNUserIdentity alloc] initWithIdentifiers:@{IDENTIFIER_TYPE_CLIENT_USER_ID: @"some-client-id", IDENTIFIER_TYPE_EMAIL: @"some-email@email.com"}];
    [api sendUserIdentity:userIdentity domain:@"some-domain"];
    
    XCTAssertTrue(sessionMock.didCallDtag);
    XCTAssertTrue(sessionMock.didCallEventsApi);
}


@end
