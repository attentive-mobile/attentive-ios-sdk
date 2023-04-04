//
//  ATTNPersistentStorage.m
//  Example
//
//  Created by Olivia Kim on 11/23/22.
//

#import "ATTNPersistentStorage.h"
#import <Foundation/Foundation.h>

static NSString *const ATTN_PERSISTENT_STORAGE_PREFIX =
    @"com.attentive.iossdk.PERSISTENT_STORAGE";

@implementation ATTNPersistentStorage

- (id)init {
  if (self = [super init]) {
    _userDefaults = [NSUserDefaults standardUserDefaults];
  }
  return self;
}

- (NSString *)getPrefixedKey:(NSString *)key {
  return
      [NSString stringWithFormat:@"%@:%@", ATTN_PERSISTENT_STORAGE_PREFIX, key];
}

- (void)saveObject:(NSObject *)value forKey:(NSString *)key {
  [_userDefaults setObject:value forKey:[self getPrefixedKey:key]];
}

- (NSString *)readStringForKey:(NSString *)key {
  return [_userDefaults stringForKey:[self getPrefixedKey:key]];
}

- (void)deleteObjectForKey:(NSString *)key {
  [_userDefaults removeObjectForKey:[self getPrefixedKey:key]];
}

@end
