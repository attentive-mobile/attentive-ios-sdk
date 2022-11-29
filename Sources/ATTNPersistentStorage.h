//
//  ATTNPersistentStorage.h
//  Example
//
//  Created by Olivia Kim on 11/23/22.
//

#ifndef ATTNPersistentStorage_h
#define ATTNPersistentStorage_h


NS_ASSUME_NONNULL_BEGIN

@interface ATTNPersistentStorage : NSObject


@property(readonly) NSUserDefaults * userDefaults;


- (void)saveObject: (NSObject *) value forKey:(NSString *) key;

- (nullable NSString *)readStringForKey: (NSString *) key;

- (void)deleteObjectForKey: (NSString *) key;


@end

NS_ASSUME_NONNULL_END


#endif /* ATTNPersistentStorage_h */
