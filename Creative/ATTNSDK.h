//
//  SDK.h
//  test
//
//  Created by Ivan Loughman-Pawelko on 7/19/22.
//
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface ATTNSDK : NSObject <WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate>

- (id)initWithDomain:(NSString *)domain;

- (id)initWithDomain:(NSString *)domain mode:(NSString *)mode;

- (void)identify: (NSString *)appUserId;

- (void)trigger:(UIView *)theView;

@end
