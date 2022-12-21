//
//  ATTNPrice.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/16/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ATTNPrice : NSObject

@property (readonly) NSDecimalNumber* price;
// the currency code, example "USD"
@property (readonly) NSString* currency;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPrice:(NSDecimalNumber*)price currency:(NSString*)currency;

@end

NS_ASSUME_NONNULL_END
