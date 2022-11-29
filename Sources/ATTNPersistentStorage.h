//
//  ATTNPersistentStorage.h
//  Example
//
//  Created by Olivia Kim on 11/23/22.
//

#ifndef ATTNPersistentStorage_h
#define ATTNPersistentStorage_h


NS_ASSUME_NONNULL_BEGIN

extern NSString * const ATTN_PERSISTENT_STORAGE_PREFIX;


@interface ATTNPersistentStorage : NSObject


- (NSString *)getPrefixedKey: (NSString * ) key;

- (void)saveObject: (NSObject *) value forKey:(NSString *) key;

- (nullable NSString *)readStringForKey: (NSString *) key;

- (void)deleteObjectForKey: (NSString *) key;

@property(readonly) NSUserDefaults * userDefaults;


@end

NS_ASSUME_NONNULL_END


#endif /* ATTNPersistentStorage_h */
