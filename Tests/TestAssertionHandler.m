//
//  ATTNEventTrackerTest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 12/16/22.
//

#import <XCTest/XCTest.h>
#import "TestAssertionHandler.h"

@implementation TestAssertionHandler

- (void)handleFailureInMethod:(SEL)selector
                       object:(id)object
                         file:(NSString *)fileName
                   lineNumber:(NSInteger)line
                  description:(NSString *)format, ...
{
    self->_wasAssertionThrown = true;
}

- (void)handleFailureInFunction:(NSString *)functionName
                           file:(NSString *)fileName
                     lineNumber:(NSInteger)line
                    description:(NSString *)format, ...
{
    self->_wasAssertionThrown = true;
}

@end
