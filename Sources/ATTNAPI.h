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

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDomain:(NSString*)domain;

- (void)sendUserIdentity:(ATTNUserIdentity *) userIdentity;

- (void)sendEvent:(id<ATTNEvent>)event userIdentity:(ATTNUserIdentity*)userIdentity;

@end

NS_ASSUME_NONNULL_END

#endif /* ATTNAPI_h */
