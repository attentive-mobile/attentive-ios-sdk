//
//  ATTNParameterValidation.h
//  Example
//
//  Created by Olivia Kim on 11/22/22.
//

#ifndef ATTNParameterValidation_h
#define ATTNParameterValidation_h

#import <Foundation/Foundation.h>

@interface ATTNParameterValidation : NSObject


+ (bool)isNotNil:(nullable NSObject *) inputValue;

+ (bool)isStringAndNotEmpty:(nullable NSObject *) inputValue;

+ (void)verifyStringOrNil:(nullable NSString *) inputValue inputName:(nonnull const NSString *) inputName;

+ (void)verify1DStringDictionaryOrNil:(nullable NSDictionary *) inputValue inputName:(nonnull const NSString *) inputName;


@end

#endif /* ATTNParameterValidation_h */
