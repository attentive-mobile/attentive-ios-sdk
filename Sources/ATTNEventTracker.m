//
//  ATTNEventTracker.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/7/22.
//

#import "ATTNEventTracker.h"
#import "ATTNSDK.h"

static ATTNEventTracker* __sharedInstance = nil;

@interface ATTNEventTracker (internal)

- (id)initWithSdk:(ATTNSDK*)sdk;

@end

@implementation ATTNEventTracker {
    ATTNSDK* _sdk;
}

+ (void)setupWithSdk:(ATTNSDK*)sdk {
    static dispatch_once_t ensureOnlyOnceToken;
    dispatch_once(&ensureOnlyOnceToken, ^{
        __sharedInstance = [[self alloc] initWithSdk:sdk];
    });
}

- (id)initWithSdk:(ATTNSDK*)sdk {
    if (self = [super init]) {
        _sdk = sdk;
    }
    
    return self;
}

- (void)recordEvent:(id<ATTNEvent>)event {
    // TODO
}

+ (instancetype)sharedInstance {
    NSAssert(__sharedInstance != nil, @"ATTNEventTracker must be setup before being used");
    return __sharedInstance;
}

// For testing
+ (void)resetInstance {
    __sharedInstance = nil;
}

@end
