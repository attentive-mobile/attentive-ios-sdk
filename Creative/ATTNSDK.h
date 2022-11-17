//
//  SDK.h
//  test
//
//  Created by Ivan Loughman-Pawelko on 7/19/22.
//
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "ATTNUserIdentifiers.h"

@interface ATTNSDK : NSObject <WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate>

NS_ASSUME_NONNULL_BEGIN

- (id)initWithDomain:(NSString *)domain;

- (id)initWithDomain:(NSString *)domain mode:(NSString *)mode;

- (void)identify: (NSString *)clientUserId;

- (void)identifyWithUserIdentifiers: (NSDictionary *)userIdentfiers;

- (void)trigger:(UIView *)theView;

NS_ASSUME_NONNULL_END

@end
