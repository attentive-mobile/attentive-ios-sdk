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


@interface ATTNVisitorService : NSObject


- (id)init;

- (NSString *)getVisitorId;

- (NSString *)createNewVisitorId;

- (NSString *)generateVisitorId;

@property(readonly) ATTNPersistentStorage * persistentStorage;


@end

NS_ASSUME_NONNULL_END


#endif /* ATTNVisitorService_h */
