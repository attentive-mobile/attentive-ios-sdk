//
//  ATTNVisitorService.m
//  Example
//
//  Created by Olivia Kim on 11/23/22.
//


#import <Foundation/Foundation.h>
#import "ATTNVisitorService.h"
#import "ATTNPersistentStorage.h"


static NSString *const VISITOR_ID_KEY = @"visitorId";


@implementation ATTNVisitorService

- (id)init {
  if (self = [super init]) {
    _persistentStorage = [[ATTNPersistentStorage alloc] init];
  }
  return self;
}

- (NSString *)getVisitorId {
  NSString *existingVisitorId = [_persistentStorage readStringForKey:VISITOR_ID_KEY];
  if (existingVisitorId != nil) {
    return existingVisitorId;
  } else {
    return [self createNewVisitorId];
  }
}

- (NSString *)createNewVisitorId {
  NSString *newVisitorId = [self generateVisitorId];
  [_persistentStorage saveObject:newVisitorId forKey:VISITOR_ID_KEY];
  return newVisitorId;
}

- (NSString *)generateVisitorId {
  NSUUID *uuid = [NSUUID UUID];
  NSString *uuidString = [[uuid UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
  return [uuidString lowercaseString];
}


@end
