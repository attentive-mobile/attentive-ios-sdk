//
//  ATTNParameterValidation.m
//  Example
//
//  Created by Olivia Kim on 11/22/22.
//

#import <Foundation/Foundation.h>
#import "ATTNParameterValidation.h"


@implementation ATTNParameterValidation


+ (bool)isNotNil:(nullable NSObject *) inputValue {
    return (inputValue != nil && ![inputValue isKindOfClass:[NSNull class]]);
}

+ (bool)isStringAndNotEmpty:(nullable NSObject *) inputValue {
    return ([inputValue isKindOfClass:[NSString class]] && [(NSData *)inputValue length] > 0);
}

+ (void)verifyStringOrNil:(nullable NSString *) inputValue inputName:(nonnull const NSString *) inputName {
    if([ATTNParameterValidation isNotNil:inputValue] && ![ATTNParameterValidation isStringAndNotEmpty:inputValue]) {
        [NSException raise:@"Bad Identifier" format:@"%@ should be a non-empty NSString", inputName];
    }
}

+ (void)verify1DStringDictionaryOrNil:(nullable NSDictionary *) inputValue inputName:(nonnull const NSString *) inputName {
    if(![ATTNParameterValidation isNotNil:inputValue]) return;
    
    if(![inputValue isKindOfClass:[NSDictionary class]]) {
        [NSException raise:@"Bad Identifier" format:@"%@ should be of form NSDictionary<NSString *, NSString *> *", inputName];
    }
    
    for(id key in inputValue) {
        [ATTNParameterValidation verifyStringOrNil:[inputValue objectForKey:key] inputName:[NSString stringWithFormat:@"%@[%@]", inputName, key]];
    }
}


@end
