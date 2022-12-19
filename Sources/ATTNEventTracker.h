//
//  ATTNEventTracker.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/6/22.
//


#ifndef ATTNEventTracker_h
#define ATTNEventTracker_h

#import <Foundation/Foundation.h>

@protocol ATTNEvent;
@class ATTNSDK;

NS_ASSUME_NONNULL_BEGIN

@interface ATTNEventTracker : NSObject

+ (void)setupWithSdk:(ATTNSDK*)sdk;

+ (instancetype)sharedInstance;

- (void)recordEvent:(id<ATTNEvent>)event;

@end

NS_ASSUME_NONNULL_END

#endif /* ATTNEventTracker_h */
