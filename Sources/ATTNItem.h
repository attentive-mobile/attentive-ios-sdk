//
//  ATTNItem.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/16/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ATTNPrice;

@interface ATTNItem : NSObject

@property (readonly) NSString* productId;
@property (readonly) NSString* productVariantId;
@property (readonly) ATTNPrice* price;
@property int quantity;
@property (nullable) NSString* productImage;
@property (nullable) NSString* name;
@property (nullable) NSString* category;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithProductId:(NSString*) productId productVariantId:(NSString*) productVariantId price:(ATTNPrice*)price;

@end

NS_ASSUME_NONNULL_END
