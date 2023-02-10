//
//  ATTNOrder.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/16/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ATTNOrder : NSObject

@property NSString* orderId;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithOrderId:(NSString*)orderId;

@end

NS_ASSUME_NONNULL_END
