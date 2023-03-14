//
//  ATTNAPI.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 11/28/22.
//

#ifndef ATTNAPI_h
#define ATTNAPI_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ATTNAPICallback)(NSData * _Nullable data, NSURL* _Nullable url, NSURLResponse * _Nullable response, NSError * _Nullable error);


@class ATTNUserIdentity;
@protocol ATTNEvent;


@interface ATTNAPI : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDomain:(NSString*)domain;

- (void)sendUserIdentity:(ATTNUserIdentity *) userIdentity;

- (void)sendUserIdentity:(ATTNUserIdentity *) userIdentity callback:(nullable ATTNAPICallback)callback;

- (void)sendEvent:(id<ATTNEvent>)event userIdentity:(ATTNUserIdentity*)userIdentity;

- (void)sendEvent:(id<ATTNEvent>)event userIdentity:(ATTNUserIdentity*)userIdentity callback:(nullable ATTNAPICallback)callback;


@end

NS_ASSUME_NONNULL_END

#endif /* ATTNAPI_h */
