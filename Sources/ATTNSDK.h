//
//  SDK.h
//  test
//
//  Created by Ivan Loughman-Pawelko on 7/19/22.
//
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>


@class ATTNUserIdentity;


@interface ATTNSDK : NSObject <WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate>

NS_ASSUME_NONNULL_BEGIN

@property (readonly) NSString* domain;

- (id)init NS_UNAVAILABLE;

- (id)initWithDomain:(NSString *)domain;

- (id)initWithDomain:(NSString *)domain mode:(NSString *)mode;

- (void)identify:(NSDictionary *)userIdentifiers;

- (void)trigger:(UIView *)theView;

- (void)clearUser;

NS_ASSUME_NONNULL_END

@end
