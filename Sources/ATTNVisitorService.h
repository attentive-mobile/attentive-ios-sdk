//
//  ATTNVisitorService.h
//  Example
//
//  Created by Olivia Kim on 11/23/22.
//

#import "ATTNPersistentStorage.h"


#ifndef ATTNVisitorService_h
#define ATTNVisitorService_h


NS_ASSUME_NONNULL_BEGIN

extern NSString * const VISITOR_ID_KEY;;

NS_ASSUME_NONNULL_END


@interface ATTNVisitorService : NSObject


- (nonnull id)init;

- (nonnull NSString *)getVisitorId;

- (nonnull NSString *)createNewVisitorId;

- (nonnull NSString *)generateVisitorId;

@property(nonnull, readonly) ATTNPersistentStorage * persistentStorage;


@end


#endif /* ATTNVisitorService_h */
