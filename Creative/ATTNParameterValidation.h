//
//  ATTNParameterValidation.h
//  Example
//
//  Created by Olivia Kim on 11/22/22.
//

#ifndef ATTNParameterValidation_h
#define ATTNParameterValidation_h

#import <Foundation/Foundation.h>

// TODO: move these classes out of the Creative/ dir
@interface ATTNParameterValidation : NSObject


+ (bool)isNotNil:(nullable NSObject *) inputValue;

+ (bool)isStringAndNotEmtpy:(nonnull NSObject *) inputValue;

+ (void)verifyString:(nullable NSString *) inputValue inputName:(nonnull const NSString *) inputName;

+ (void)verify1DStringDictionary:(nonnull NSDictionary *) inputValue inputName:(nonnull const NSString *) inputName;


@end

#endif /* ATTNParameterValidation_h */
