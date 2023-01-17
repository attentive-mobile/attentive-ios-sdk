//
//  ATTNProductViewEvent.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 1/17/23.
//

#import <Foundation/Foundation.h>
#import "ATTNEvent.h"

NS_ASSUME_NONNULL_BEGIN

@class ATTNItem;

@interface ATTNProductViewEvent : NSObject<ATTNEvent>

@property (readonly) NSArray<ATTNItem*>* items;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithItems:(NSArray<ATTNItem*>*)items;

@end

NS_ASSUME_NONNULL_END
