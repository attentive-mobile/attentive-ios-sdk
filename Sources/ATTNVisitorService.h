//
//  ATTNVisitorService.h
//  Example
//
//  Created by Olivia Kim on 11/23/22.
//

@class ATTNPersistentStorage;


#ifndef ATTNVisitorService_h
#define ATTNVisitorService_h


NS_ASSUME_NONNULL_BEGIN


@interface ATTNVisitorService : NSObject


@property(readonly) ATTNPersistentStorage * persistentStorage;


- (id)init;

- (NSString *)getVisitorId;

- (NSString *)createNewVisitorId;


@end

NS_ASSUME_NONNULL_END


#endif /* ATTNVisitorService_h */
