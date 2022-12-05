//
//  ATTNAPI.m
//  attentive-ios-sdk
//
//  Created by Wyatt Davis on 11/28/22.
//

#import <Foundation/Foundation.h>

#import "ATTNParameterValidation.h"
#import "ATTNUserIdentity.h"
#import "ATTNAPI.h"

static NSString* const DTAG_URL_FORMAT = @"https://cdn.attn.tv/%@/dtag.js";
static NSString* const EXTERNAL_VENDOR_TYPE_SHOPIFY = @"0";
static NSString* const EXTERNAL_VENDOR_TYPE_KLAVIYO = @"1";
static NSString* const EXTERNAL_VENDOR_TYPE_CLIENT_USER = @"2";
static NSString* const EXTERNAL_VENDOR_TYPE_CUSTOM_USER = @"6";

@implementation ATTNAPI {
    NSString* _Nullable _domain;
    NSURLSession* _Nonnull _urlSession;
}

- (id)init {
    if (self = [super init]) {
        // It is possible that this is unsafe. If the host app chooses to change the config for the shared NSURLSession then our HTTP calls may be impacted. An alternative is to create our own NSURLSession instance.
        _urlSession = [NSURLSession sharedSession];
    }
    return [super init];
}

- (void)sendUserIdentity:(ATTNUserIdentity *)userIdentity domain:(NSString *)domain {
    // TODO we should add retries for transient errors
    [self getGeoAdjustedDomain:domain completionHandler:^(NSString* geoAdjustedDomain, NSError* error) {
        if (error) {
            NSLog(@"Error sending user identity: '%@'", error);
            return;
        }
        
        [self sendUserIdentityInternal:userIdentity domain:geoAdjustedDomain];
    }];
}

- (void)getGeoAdjustedDomain:(NSString *)domain completionHandler:(void (^)(NSString* _Nullable, NSError* _Nullable)) completionHandler {
    NSString* urlString = [NSString stringWithFormat:DTAG_URL_FORMAT, domain];
    
    NSURL* url = [NSURL URLWithString:urlString];
    NSURLSessionDataTask* task = [_urlSession dataTaskWithURL:url completionHandler:^ void (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error getting the geo-adjusted domain. Error: '%@'", [error description]);
            completionHandler(nil, error);
            return;
        }
        
        // The response is an HTTP response because the URL had an HTTPS scheme
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
        // The body/data only contains the tag data if the endpoint returns a 200
        if ([httpResponse statusCode] != 200) {
            NSLog(@"Error getting the geo-adjusted domain. Incorrect status code: '%ld'", (long)[httpResponse statusCode]);
            completionHandler(nil, [NSError errorWithDomain:@"com.attentive.API" code:NSURLErrorBadServerResponse userInfo:nil]);
            return;
        }
        
        NSString* dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        NSString* geoAdjustedDomain = [ATTNAPI extractDomainFromTag:dataString];
        
        if (!geoAdjustedDomain) {
            NSError* error = [NSError errorWithDomain:@"com.attentive.API" code:NSURLErrorBadServerResponse userInfo:nil];
            completionHandler(nil, error);
            return;
        }
        
        completionHandler(geoAdjustedDomain, nil);
    }];
    
    [task resume];
}

- (void)sendUserIdentityInternal:(ATTNUserIdentity *)userIdentity domain:(NSString *)domain {
    NSURL* url = [self constructUserIdentityUrl:userIdentity domain:domain];
    NSURLSessionDataTask* task = [_urlSession dataTaskWithURL:url completionHandler:^ void (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error sending user identity. Error: '%@'", [error description]);
            return;
        }
        
        // The response is an HTTP response because the URL had an HTTPS scheme
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
        if ([httpResponse statusCode] != 200) {
            NSLog(@"Error sending the event. Incorrect status code: '%ld'", (long)[httpResponse statusCode]);
            return;
        }
        
        NSLog(@"Successfully sent user identity event");
    }];
    
    [task resume];
}

- (NSURL*)constructUserIdentityUrl:(ATTNUserIdentity *)userIdentity domain:(NSString *)domain {
    NSURLComponents* urlComponents = [[NSURLComponents alloc] initWithString:@"https://events.attentivemobile.com/e"];
    
    NSMutableDictionary* queryParams = [[NSMutableDictionary alloc] init];
    queryParams[@"v"] = @"mobile-app";
    queryParams[@"c"] = domain;
    queryParams[@"t"] = @"idn";
    queryParams[@"lt"] = @"0";
    queryParams[@"evs"] = [self buildExternalVendorIdsJson:userIdentity];
    queryParams[@"m"] = [self buildMetadataJson:userIdentity];
    queryParams[@"u"] = userIdentity.visitorId;
    
    // create query "items" for each query param
    NSMutableArray *queryItems = [NSMutableArray array];
    for (NSString *key in queryParams) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:queryParams[key]]];
    }
    
    urlComponents.queryItems = queryItems;
    
    return urlComponents.URL;
}

- (NSString*)buildExternalVendorIdsJson:(ATTNUserIdentity*)userIdentity {
    NSMutableArray* ids = [[NSMutableArray alloc] init];
    if (userIdentity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]) {
        [ids addObject:@{@"vendor": EXTERNAL_VENDOR_TYPE_CLIENT_USER, @"id": userIdentity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]}];
    }
    if (userIdentity.identifiers[IDENTIFIER_TYPE_KLAVIYO_ID]) {
        [ids addObject:@{@"vendor": EXTERNAL_VENDOR_TYPE_KLAVIYO, @"id": userIdentity.identifiers[IDENTIFIER_TYPE_KLAVIYO_ID]}];
    }
    if (userIdentity.identifiers[IDENTIFIER_TYPE_SHOPIFY_ID]) {
        [ids addObject:@{@"vendor": EXTERNAL_VENDOR_TYPE_SHOPIFY, @"id": userIdentity.identifiers[IDENTIFIER_TYPE_SHOPIFY_ID]}];
    }
    if (userIdentity.identifiers[IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS]) {
        NSDictionary* customIdentifiers = userIdentity.identifiers[IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS];
        for (id key in customIdentifiers) {
            [ids addObject:@{@"vendor": EXTERNAL_VENDOR_TYPE_CUSTOM_USER, @"id": customIdentifiers[key], @"name": key}];
        }
    }

    NSError* error = nil;
    NSData* array = [NSJSONSerialization dataWithJSONObject:ids options:0 error:&error];
    
    if (error) {
        NSLog(@"Could not serialize the external vendor ids. Returning an empty array. Error: '%@'", [error description]);
        return @"[]";
    }
    
    return [[NSString alloc] initWithData:array encoding:NSUTF8StringEncoding];
}

- (NSString*)buildMetadataJson:(ATTNUserIdentity*)userIdentity {
    NSMutableDictionary* metadata = [[NSMutableDictionary alloc] init];
    metadata[@"source"] = @"msdk";
    if (userIdentity.identifiers[IDENTIFIER_TYPE_PHONE]) {
        metadata[@"phone"] = userIdentity.identifiers[IDENTIFIER_TYPE_PHONE];
    }
    if (userIdentity.identifiers[IDENTIFIER_TYPE_EMAIL]) {
        metadata[@"email"] = userIdentity.identifiers[IDENTIFIER_TYPE_EMAIL];
    }
    
    NSError* error = nil;
    NSData* json = [NSJSONSerialization dataWithJSONObject:metadata options:0 error:&error];
    
    if (error) {
        NSLog(@"Could not serialize the external vendor ids. Returning an empty blob. Error: '%@'", [error description]);
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

+ (NSString* _Nullable)extractDomainFromTag:(NSString *)tag {
    NSError *error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"window.__attentive_domain='(.*?).attn.tv'" options:0 error:&error];
    
    if (error) {
        NSLog(@"Error building the domain regex. Error: '%@'", [error description]);
        return nil;
    }
    
    NSInteger matchesCount = [regex numberOfMatchesInString:tag options:0 range:NSMakeRange(0, [tag length])];
    if (matchesCount < 1) {
        NSLog(@"No Attentive domain found in the tag");
        return nil;
    } else if (matchesCount > 1) {
        NSLog(@"More than one match found for the Attentive domain regex. Continuing with the first one...");
    }
    
    NSTextCheckingResult* regexResult = [regex firstMatchInString:tag options:0 range:NSMakeRange(0, [tag length])];
    if (!regexResult) {
        NSLog(@"No Attentive domain regex match object returned.");
        return nil;
    }
    
    NSRange domainRange = [regexResult rangeAtIndex:1];
    if (NSEqualRanges(domainRange, NSMakeRange(NSNotFound, 0))) {
        NSLog(@"No match found for Attentive domain in the tag.");
        return nil;
    }
    
    return [tag substringWithRange:domainRange];
}

- (NSURLSession*)session {
    return _urlSession;
}

- (void)setSession:(NSURLSession*)session {
    _urlSession = session;
}

@end
