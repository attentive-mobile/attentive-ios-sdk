//
//  ATTNParameterValidation.m
//  Example
//
//  Created by Olivia Kim on 11/22/22.
//

#import <Foundation/Foundation.h>


@implementation ATTNParameterValidation : NSObject


+ (bool)isNotNil:(nullable NSObject *) inputValue {
    return (inputValue != nil && ![inputValue isKindOfClass:[NSNull class]]);
}

+ (bool)isStringAndNotEmtpy:(nonnull NSObject *) inputValue {
    return ([inputValue isKindOfClass:[NSString class]] && [(NSData *)inputValue length] > 0);
}

+ (void)verifyString:(nullable NSString *) inputValue inputName:(nonnull const NSString *) inputName {
    if([self isNotNil:inputValue] && ![self isStringAndNotEmtpy:inputValue]) {
        [NSException raise:@"Bad Identifier" format:@"%@ should be a non-empty NSString", inputName];
    }
}

+ (void)verify1DStringDictionary:(nonnull NSDictionary *) inputValue inputName:(nonnull const NSString *) inputName {
    if(![self isNotNil:inputValue]) return;
    
    if(![inputValue isKindOfClass:[NSDictionary class]]) {
        [NSException raise:@"Bad Identifier" format:@"%@ should be of form NSDictionary<NSString *, NSString *> *", inputName];
    }
    
    for(id key in inputValue) {
        [self verifyString:[inputValue objectForKey:key] inputName:[NSString stringWithFormat:@"%@[%@]", inputName, key]];
    }
}


@end
