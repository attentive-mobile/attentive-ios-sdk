//
//  ATTNPersistentStorage.h
//  Example
//
//  Created by Olivia Kim on 11/23/22.
//

#ifndef ATTNPersistentStorage_h
#define ATTNPersistentStorage_h


NS_ASSUME_NONNULL_BEGIN

extern NSString * const ATTN_PREFIX;

NS_ASSUME_NONNULL_END


@interface ATTNPersistentStorage : NSObject


- (nonnull NSString *)getPrefixedKey: (nonnull NSString * ) key;

- (void)saveObject: (nonnull NSObject *) value forKey:(nonnull NSString *) key;

- (nullable NSString *)readStringForKey: (nonnull NSString *) key;

- (void)deleteObjectForKey: (nonnull NSString *) key;

@property(nonnull, readonly) NSUserDefaults * userDefaults;


@end


#endif /* ATTNPersistentStorage_h */
