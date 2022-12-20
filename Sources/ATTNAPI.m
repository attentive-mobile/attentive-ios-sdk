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
#import "ATTNEvent.h"
#import "ATTNItem.h"
#import "ATTNPrice.h"
#import "ATTNOrder.h"
#import "ATTNCart.h"
#import "ATTNPurchaseEvent.h"

// A single event can create multiple requests. The EventRequest class represents a single request.
@interface EventRequest : NSObject

@property (readonly) NSMutableDictionary* metadata;
@property (readonly) NSString* eventNameAbbreviation;

-(instancetype)initWithMetadata:(NSMutableDictionary*)metadata eventNameAbbreviation:(NSString*)abbreviation;

@end

@implementation EventRequest

-(instancetype)initWithMetadata:(NSMutableDictionary*)metadata eventNameAbbreviation:(NSString*)abbreviation {
    if (self = [super init]) {
        self->_metadata = metadata;
        self->_eventNameAbbreviation = abbreviation;
    }
    
    return self;
}

@end

@interface NSMutableDictionary (Custom)

- (void)addEntryIfNotNil:(NSString*)key value:(NSObject * _Nullable )value;

@end

@implementation NSMutableDictionary (Custom)

- (void)addEntryIfNotNil:(NSString*)key value:(NSObject * _Nullable )value {
    if (value != nil) {
        self[key] = value;
    }
}

@end

static NSString* const DTAG_URL_FORMAT = @"https://cdn.attn.tv/%@/dtag.js";
static NSString* const EXTERNAL_VENDOR_TYPE_SHOPIFY = @"0";
static NSString* const EXTERNAL_VENDOR_TYPE_KLAVIYO = @"1";
static NSString* const EXTERNAL_VENDOR_TYPE_CLIENT_USER = @"2";
static NSString* const EXTERNAL_VENDOR_TYPE_CUSTOM_USER = @"6";

@implementation ATTNAPI {
    NSURLSession* _Nonnull _urlSession;
    NSNumberFormatter* _Nonnull _priceFormatter;
}

- (id)init {
    return [self initWithUrlSession:[NSURLSession sharedSession]];
}

// Private constructor that makes testing easier
- (instancetype)initWithUrlSession:(NSURLSession*)urlSession {
    if (self = [super init]) {
        _urlSession = urlSession;
        _priceFormatter = [NSNumberFormatter new];
        [_priceFormatter setMinimumFractionDigits:2];
    }
    
    return [super init];
}

// TODO: When we add the other events, the USER_IDENTIFIER_COLLECTED event code will be wrapped into the generic event code
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

- (void)sendEvent:(id<ATTNEvent>)event userIdentity:(ATTNUserIdentity*)userIdentity domain:(NSString*) domain {
    [self getGeoAdjustedDomain:domain completionHandler:^(NSString* geoAdjustedDomain, NSError* error) {
        if (error) {
            NSLog(@"Error sending user identity: '%@'.", error);
            
        }
        
        [self sendEventInternal:event userIdentity:userIdentity domain:domain];
    }];
}

- (void)sendEventInternal:(id<ATTNEvent>)event userIdentity:(ATTNUserIdentity*)userIdentity domain:(NSString*) domain {
    // slice up the Event into individual EventRequests
    NSArray<EventRequest *>* requests = [self convertEventToRequests:event];
    
    for (EventRequest* request in requests) {
        [self sendEventInternalForRequest:request userIdentity:userIdentity domain:domain];
    }
}

- (void)sendEventInternalForRequest:(EventRequest*)request userIdentity: (ATTNUserIdentity*)userIdentity domain:(NSString*) domain {
    NSURL* url = [self constructEventUrlComponentsForEventRequest:request userIdentity:userIdentity domain:domain].URL;

    NSURLSessionDataTask* task = [_urlSession dataTaskWithURL:url completionHandler:^ void (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error sending for event '%@'. Error: '%@'", request.eventNameAbbreviation, [error description]);
            return;
        }
        
        // The response is an HTTP response because the URL had an HTTPS scheme
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
        if ([httpResponse statusCode] != 200) {
            NSLog(@"Error sending the event '%@'. Incorrect status code: '%ld'", request.eventNameAbbreviation, (long)[httpResponse statusCode]);
            return;
        }
        
        NSLog(@"%@", [NSString stringWithFormat:@"Successfully sent event of type '%@'", request.eventNameAbbreviation]);
    }];
    
    [task resume];
}

// A single event can create multiple requests to our servers. This method converts an event to multiple request objects.
- (NSArray<EventRequest *>*)convertEventToRequests:(id<ATTNEvent>)event {
    if ([event isKindOfClass:[ATTNPurchaseEvent class]]) {
        ATTNPurchaseEvent* purchase = (ATTNPurchaseEvent*)event;
        
        NSDecimalNumber* cartTotal = [NSDecimalNumber zero];
        NSMutableArray<EventRequest*>* eventRequests = [[NSMutableArray alloc] init];
        for (ATTNItem* item in purchase.items) {
            NSMutableDictionary* metadata = [[NSMutableDictionary alloc] init];

            metadata[@"productId"] = item.productId;
            metadata[@"subProductId"] = item.productVariantId;
            metadata[@"price"] = [_priceFormatter stringFromNumber:item.price.price];
            metadata[@"currency"] = item.price.currency;
            metadata[@"quantity"] = [NSString stringWithFormat:@"%d", item.quantity];
            [metadata addEntryIfNotNil:@"category" value:item.category];
            [metadata addEntryIfNotNil:@"image" value:item.productImage];
            [metadata addEntryIfNotNil:@"name" value:item.name];
            
            metadata[@"orderId"] = purchase.order.orderId;
            
            if (purchase.cart != nil) {
                [metadata addEntryIfNotNil:@"cartId" value:purchase.cart.cartId];
                [metadata addEntryIfNotNil:@"cartCoupon" value:purchase.cart.cartCoupon];
            }
            
            [eventRequests addObject:[[EventRequest alloc] initWithMetadata:metadata eventNameAbbreviation:@"p"]];
            
            cartTotal = [cartTotal decimalNumberByAdding:item.price.price];
        }
        
        // Add cart total to each metadata
        NSString* cartTotalString = [_priceFormatter stringFromNumber:cartTotal];
        for (EventRequest* eventRequest in eventRequests) {
            eventRequest.metadata[@"cartTotal"] = cartTotalString;
        }
        
        return eventRequests;
    } else {
        NSException *e = [NSException
                exceptionWithName:@"UnknownEventException"
                reason:[NSString stringWithFormat:@"Unknown Event type: %@", [event class]]
                userInfo:nil];
            @throw e;
    }
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
    NSURL* url = [self constructUserIdentityUrl:userIdentity domain:domain].URL;
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

- (NSURLComponents*)constructEventUrlComponentsForEventRequest:(EventRequest*)eventRequest userIdentity:(ATTNUserIdentity *)userIdentity domain:(NSString *)domain {
    NSURLComponents* urlComponents = [[NSURLComponents alloc] initWithString:@"https://events.attentivemobile.com/e"];
    
    NSMutableDictionary* queryParams = [self constructBaseQueryParams:userIdentity domain:domain];
    NSMutableDictionary* combinedMetadata = [self buildBaseMetadata:userIdentity];
    [combinedMetadata addEntriesFromDictionary:eventRequest.metadata];
    queryParams[@"m"] = [self convertDictionaryToJson:combinedMetadata];
    queryParams[@"t"] = eventRequest.eventNameAbbreviation;
    
    NSMutableArray *queryItems = [NSMutableArray array];
    for (NSString *key in queryParams) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:queryParams[key]]];
    }
    
    urlComponents.queryItems = queryItems;
    
    return urlComponents;
}

- (NSMutableDictionary*)constructBaseQueryParams:(ATTNUserIdentity*)userIdentity domain:(NSString*)domain {
    NSMutableDictionary* queryParams = [[NSMutableDictionary alloc] init];
    queryParams[@"v"] = @"mobile-app";
    queryParams[@"c"] = domain;
    queryParams[@"lt"] = @"0";
    queryParams[@"evs"] = [self buildExternalVendorIdsJson:userIdentity];
    queryParams[@"u"] = userIdentity.visitorId;
    return queryParams;
}

- (NSURLComponents*)constructUserIdentityUrl:(ATTNUserIdentity *)userIdentity domain:(NSString *)domain {
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
    
    return urlComponents;
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
    NSMutableDictionary* metadata = [self buildBaseMetadata:userIdentity];
    
    NSError* error = nil;
    NSData* json = [NSJSONSerialization dataWithJSONObject:metadata options:0 error:&error];
    
    if (error) {
        NSLog(@"Could not serialize the external vendor ids. Returning an empty blob. Error: '%@'", [error description]);
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

// Will return an empty dictionary if there are any issues
- (NSString*)convertDictionaryToJson:(NSDictionary*)dictionary {
    NSError* error = nil;
    NSData* json = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    
    if (error) {
        NSLog(@"Could not serialize the dictionary to JSON. Returning an empty blob. Error: '%@'", [error description]);
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

- (NSMutableDictionary*)buildBaseMetadata:(ATTNUserIdentity*)userIdentity {
    NSMutableDictionary* metadata = [[NSMutableDictionary alloc] init];
    metadata[@"source"] = @"msdk";
    if (userIdentity.identifiers[IDENTIFIER_TYPE_PHONE]) {
        metadata[@"phone"] = userIdentity.identifiers[IDENTIFIER_TYPE_PHONE];
    }
    if (userIdentity.identifiers[IDENTIFIER_TYPE_EMAIL]) {
        metadata[@"email"] = userIdentity.identifiers[IDENTIFIER_TYPE_EMAIL];
    }
    return metadata;
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

// For testing only
- (NSURLSession*)session {
    return _urlSession;
}

// For testing only
- (void)setSession:(NSURLSession*)session {
    _urlSession = session;
}

@end
