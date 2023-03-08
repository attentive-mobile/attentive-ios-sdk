//
//  ATTNAPI.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 11/28/22.
//

#ifndef ATTNAPI_h
#define ATTNAPI_h

#import <Foundation/Foundation.h>

typedef void (^ATTNAPICallback)(NSURL* _Nullable url, NSURLResponse *response, NSError *error);


@class ATTNUserIdentity;
@protocol ATTNEvent;

NS_ASSUME_NONNULL_BEGIN

@interface ATTNAPI : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDomain:(NSString*)domain;

- (void)sendUserIdentity:(ATTNUserIdentity *) userIdentity;

- (void)sendUserIdentity:(ATTNUserIdentity *) userIdentity callback:(ATTNAPICallback)callback;

- (void)sendEvent:(id<ATTNEvent>)event userIdentity:(ATTNUserIdentity*)userIdentity;

- (void)sendEvent:(id<ATTNEvent>)event userIdentity:(ATTNUserIdentity*)userIdentity callback:(ATTNAPICallback)callback;


@end

NS_ASSUME_NONNULL_END

#endif /* ATTNAPI_h */
