//
//  ATTNCustomEvent.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 3/20/23.
//

#import <Foundation/Foundation.h>
#import "ATTNEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface ATTNCustomEvent : NSObject<ATTNEvent>

@property (readonly) NSString* type;

@property (readonly) NSDictionary* properties;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithType:(NSString*)type properties:(NSDictionary<NSString*, NSString*>*)properties;

@end

NS_ASSUME_NONNULL_END
