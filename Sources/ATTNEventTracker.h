//
//  ATTNEventTracker.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/6/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ATTNEvent;
@class ATTNSDK;

@interface ATTNEventTracker : NSObject

+ (void)setupWithSdk:(ATTNSDK*)sdk;

+ (instancetype)sharedInstance;

- (void)recordEvent:(id<ATTNEvent>)event;

@end

NS_ASSUME_NONNULL_END
