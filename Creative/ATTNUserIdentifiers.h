//
//  ATTNUserIdentifiers.h
//  Example
//
//  Created by Wyatt Davis on 11/9/22.
//

#import <Foundation/Foundation.h>

@interface ATTNUserIdentifiers : NSObject

- (nonnull id)initWithUserIdentifiers:(nonnull NSDictionary *) userIdentifiers;

@property (readonly, nonnull) NSString * clientUserId;
@property (readonly, nullable) NSString * email;
@property (readonly, nullable) NSString * phone;
@property (readonly, nullable) NSString * klaviyoId;
@property (readonly, nullable) NSString * shopifyId;
@property (readonly, nullable) NSDictionary<NSString *, NSString *> * customIdentifiers;

@end
