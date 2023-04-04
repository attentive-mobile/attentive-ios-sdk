//
//  ATTNCustomEvent.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 3/20/23.
//

#import "ATTNCustomEvent.h"

@implementation ATTNCustomEvent

- (instancetype)initWithType:(NSString*)type properties:(NSDictionary<NSString*, NSString*>*)properties {
  if (self = [super init]) {
    _type = type;
    _properties = [[NSDictionary alloc] initWithDictionary:properties];
  }

  return self;
}

@end
