//
//  ATTNCustomEvent.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 3/20/23.
//

#import "ATTNCustomEvent.h"
#import "attentive_ios_sdk_framework/attentive_ios_sdk_framework-Swift.h"

@implementation ATTNCustomEvent

- (instancetype)initWithType:(NSString *)type properties:(NSDictionary<NSString *, NSString *> *)properties {
  if (self = [super init]) {
    [ATTNParameterValidation verifyNotNil:type inputName:@"type"];
    [ATTNParameterValidation verifyStringOrNil:type inputName:@"type"];

    NSString *invalidCharInType = [ATTNCustomEvent findInvalidCharacterInType:type];
    if (invalidCharInType != nil) {
      NSLog(@"Invalid character '%@' in CustomEvent type '%@'", invalidCharInType, type);
      return nil;
    }

    [ATTNParameterValidation verifyNotNil:properties inputName:@"properties"];
    [ATTNParameterValidation verify1DStringDictionaryOrNil:properties inputName:@"properties"];

    for (NSString *key in properties.allKeys) {
      NSString *invalidCharInKey = [ATTNCustomEvent findInvalidCharacterInPropertiesKey:key];
      if (invalidCharInKey != nil) {
        NSLog(@"ERROR: Invalid character '%@' in CustomEvent property key '%@'", invalidCharInKey, key);
        return nil;
      }
    }

    _type = type;
    _properties = [[NSDictionary alloc] initWithDictionary:properties];
  }

  return self;
}

+ (NSString *)findInvalidCharacterInType:(NSString *)type {
  NSArray *invalidCharacters = @[ @"\"", @"'", @"(", @")", @"{", @"}", @"[", @"]", @"\\", @"|", @"," ];
  return [self findCharacterInString:type charactersToFind:invalidCharacters];
}

+ (NSString *)findInvalidCharacterInPropertiesKey:(NSString *)key {
  NSArray *invalidCharacters = @[ @"\"", @"{", @"}", @"[", @"]", @"\\", @"|" ];

  return [self findCharacterInString:key charactersToFind:invalidCharacters];
}

+ (NSString *)findCharacterInString:(NSString *)input charactersToFind:(NSArray *)charactersToFind {
  for (NSString *character in charactersToFind) {
    if ([input rangeOfString:character].location != NSNotFound) {
      return character;
    }
  }
  return nil;
}

@end
