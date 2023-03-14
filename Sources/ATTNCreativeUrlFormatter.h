//
//  ATTNCreativeUrlFormatter.h
//  attentive-ios-sdk
//
//  Created by Olivia Kim on 3/9/23.
//

#import "ATTNUserIdentity.h"

#ifndef ATTNCreativeUrlFormatter_h
#define ATTNCreativeUrlFormatter_h

#endif /* ATTNCreativeUrlFormatter_h */


@interface ATTNCreativeUrlFormatter : NSObject

NS_ASSUME_NONNULL_BEGIN

+ (nonnull NSString *)buildCompanyCreativeUrlForDomain:(NSString *)domain
                                                  mode:(NSString *)mode
                                          userIdentity:(ATTNUserIdentity *)userIdentity;

NS_ASSUME_NONNULL_END

@end
