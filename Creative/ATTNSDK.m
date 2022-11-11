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
    NSString *_appUserId;
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

- (void)identify: (NSString *)appUserId {
    _appUserId = appUserId;
}

- (void)trigger:(UIView *)theView {
    _parentView = theView;
    NSLog(@"Called showWebView in creativeSDK with domain: %@", _domain);
    NSString* creativePageUrl;
    if ([_appUserId length] == 0) {
        [NSException raise:@"Missing Attentive Identity" format:@"No appUserId registered. `identify` must be called before `trigger`."];
    }

    if ([_mode isEqual:@"debug"]) {
        creativePageUrl = [NSString stringWithFormat:@"https://creatives.attn.tv/mobile-apps/index.html?domain=%@&app_user_id=%@&debug=matter-trip-grass-symbol", _domain, _appUserId];
    } else {
        creativePageUrl = [NSString stringWithFormat:@"https://creatives.attn.tv/mobile-apps/index.html?domain=%@&app_user_id=%@", _domain, _appUserId];
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
    "    const interval = setInterval(function() {"
    "        e = document.querySelector('iframe');"
    "        if(e && e.id === 'attentive_creative') {"
    "           clearInterval(interval);"
    "           resolve(e.id);"
    "        }"
    "    }, 100);"
    "    setTimeout(function() {"
    "        clearInterval(interval);"
    "        resolve(undefined);"
    "    }, 5000);"
    "}); "
    "var iframeId = await p; "
    "return iframeId;";

    [webView callAsyncJavaScript:asyncJs arguments:nil inFrame:nil inContentWorld:WKContentWorld.defaultClientWorld completionHandler:^(NSString *creativeIframeId, NSError *error) {
        if (!creativeIframeId) {
            NSLog(@"Creative timed out. Not showing WebView.");
            return;
        } else if ([creativeIframeId isEqual:@"attentive_creative"] && ![self->_mode isEqual:@"debug"]) {
            [self->_parentView addSubview:webView];
        } else {
            NSLog(@"Received unknown creativeIframeId: %@", creativeIframeId);
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
