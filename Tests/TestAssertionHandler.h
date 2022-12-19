//
//  TestAssertionHandler.h
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 12/16/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// An implementation of an NSAssertionHandler that catches any asserts and sets the 'wasAssertionThrown' property to true
@interface TestAssertionHandler : NSAssertionHandler

@property bool wasAssertionThrown;

@end

NS_ASSUME_NONNULL_END
