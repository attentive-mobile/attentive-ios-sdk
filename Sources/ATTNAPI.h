//
//  ATTNAPI.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 11/28/22.
//

#ifndef ATTNAPI_h
#define ATTNAPI_h

#import <Foundation/Foundation.h>

@class ATTNUserIdentity;
@protocol ATTNEvent;

NS_ASSUME_NONNULL_BEGIN

@interface ATTNAPI : NSObject

- (instancetype)init;

- (void)sendUserIdentity:(ATTNUserIdentity *) userIdentity domain:(NSString *) domain;

- (void)sendEvent:(id<ATTNEvent>)event userIdentity:(ATTNUserIdentity*)userIdentity domain:(NSString*) domain;

@end

NS_ASSUME_NONNULL_END

#endif /* ATTNAPI_h */
