//
//  CreativeSDK.m
//  test
//
//  Created by Ivan Loughman-Pawelko on 7/19/22.
//

#import <WebKit/WebKit.h>
#import "ATTNSDK.h"

@implementation ATTNSDK {
    UIView *_parentView;
    WKWebView *_webView;
    NSString *_domain;
    NSString *_mode;
    ATTNUserIdentity *_userIdentity;
}

- (id)initWithDomain:(NSString *)domain {
    _domain = domain;
    return [super init];
}

- (id)initWithDomain:(NSString *)domain mode:(NSString *)mode {
    _domain = domain;
    _mode = mode;
    return [super init];
}

- (void)identify:(NSDictionary *)userIdentfiers {
    _userIdentity = [[ATTNUserIdentity alloc] initWithIdentifiers:userIdentfiers];
}

- (void)trigger:(UIView *)theView {
    _parentView = theView;
    NSLog(@"Called showWebView in creativeSDK with domain: %@", _domain);
    NSString* creativePageUrl;

    if ([_mode isEqual:@"debug"]) {
        creativePageUrl = [NSString stringWithFormat:@"https://creatives.attn.tv/mobile-apps/index.html?domain=%@&cuid=%@&debug=matter-trip-grass-symbol", _domain, _userIdentity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]];
    } else {
        creativePageUrl = [NSString stringWithFormat:@"https://creatives.attn.tv/mobile-apps/index.html?domain=%@&cuid=%@", _domain, _userIdentity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]];
    }

    NSLog(@"Requesting creative page url: %@", creativePageUrl);
    
    NSURL *url = [NSURL URLWithString:creativePageUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    WKWebViewConfiguration *wkWebViewConfiguration = [[WKWebViewConfiguration alloc] init];
    
    [[wkWebViewConfiguration userContentController] addScriptMessageHandler:self name:@"log"];
    
    NSString *userScriptWithEventListener = @"window.addEventListener('message', (event) => {if (event.data && event.data.__attentive && event.data.__attentive.action === 'CLOSE') {window.webkit.messageHandlers.log.postMessage(event.data.__attentive.action);}}, false);";
    
    WKUserScript *wkUserScript = [[WKUserScript alloc] initWithSource:userScriptWithEventListener injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:FALSE];
    [[wkWebViewConfiguration userContentController] addUserScript:wkUserScript];
    
    _webView = [[WKWebView alloc] initWithFrame:theView.frame configuration:wkWebViewConfiguration];
    _webView.navigationDelegate = self;

    [_webView loadRequest:request ];
    
    if ([_mode isEqual:@"debug"]) {
        [_parentView addSubview:_webView];
    }
    else {
        _webView.opaque = NO;
        _webView.backgroundColor = [UIColor clearColor];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {

    NSString *asyncJs = @"var p = new Promise(resolve => { "
        "setTimeout(() => { "
            "resolve(document.querySelector('iframe').id); "
        "}, 1000); "
    "}); "
    "var iframe = await p; "
    "return iframe;";

    [webView callAsyncJavaScript:asyncJs arguments:nil inFrame:nil inContentWorld:WKContentWorld.defaultClientWorld completionHandler:^(NSString *id, NSError *error) {
        if ([id isEqual:@"attentive_creative"] && ![self->_mode isEqual:@"debug"]) {
            [self->_parentView addSubview:webView];
        }
    }];
}


- (void)userContentController:(WKUserContentController *)userContentController
    didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isEqual:@"CLOSE"]) {
        [_webView removeFromSuperview];
    }
}


- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if ([navigationAction.request.URL.scheme isEqual:@"sms"]) {
        [UIApplication.sharedApplication openURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}


@end
