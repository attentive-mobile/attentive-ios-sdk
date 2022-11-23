//
//  ATTNPersistentStorage.m
//  Example
//
//  Created by Olivia Kim on 11/23/22.
//

#import <Foundation/Foundation.h>
#import "ATTNPersistentStorage.h"


NSString * const ATTN_PREFIX = @"com.attentive.iossdk.PERSISTENT_STORAGE";


@implementation ATTNPersistentStorage


- (id)init {
    _userDefaults = [NSUserDefaults standardUserDefaults];
    return [super init];
}

- (NSString *)getPrefixedKey: (nonnull NSString * ) key {
    return [NSString stringWithFormat:@"%@:%@", ATTN_PREFIX, key];
}

- (void)saveObject: (nonnull NSObject *) value forKey:(nonnull NSString *) key {
    [_userDefaults setObject:value forKey:[self getPrefixedKey:key]];
}

- (NSString *)readStringForKey: (nonnull NSString *) key {
    return [_userDefaults stringForKey:[self getPrefixedKey:key]];
}

- (void)deleteForKey: (nonnull NSString *) key {
    [_userDefaults removeObjectForKey:[self getPrefixedKey:key]];
}


@end
