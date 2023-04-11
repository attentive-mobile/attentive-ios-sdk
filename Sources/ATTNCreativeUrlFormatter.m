//
//  CreativeUrlFormatter.m
//  attentive-ios-sdk
//
//  Created by Olivia Kim on 3/9/23.
//

#import "ATTNCreativeUrlFormatter.h"
#import "Internal/ATTNAppInfo.h"

@implementation ATTNCreativeUrlFormatter

+ (nonnull NSString *)buildCompanyCreativeUrlForDomain:(NSString *)domain
                                                  mode:(NSString *)mode
                                          userIdentity:(ATTNUserIdentity *)userIdentity {

  NSURLComponents *components = [[NSURLComponents alloc] initWithString:@"https://creatives.attn.tv/mobile-apps/index.html"];

  // Add query parameters
  NSMutableArray *queryItems = [[NSMutableArray alloc] initWithObjects:
                                                           [[NSURLQueryItem alloc] initWithName:@"domain"
                                                                                          value:domain],
                                                           nil];

  if ([mode isEqualToString:@"debug"]) {
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:mode value:@"matter-trip-grass-symbol"]];
  }

  if (userIdentity.visitorId != nil) {
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"vid" value:userIdentity.visitorId]];
  } else {
    NSLog(@"ERROR: No Visitor ID Found. This should not happen.");
  }

  if (userIdentity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID] != nil) {
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"cuid" value:userIdentity.identifiers[IDENTIFIER_TYPE_CLIENT_USER_ID]]];
  }

  if (userIdentity.identifiers[IDENTIFIER_TYPE_PHONE] != nil) {
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"p" value:userIdentity.identifiers[IDENTIFIER_TYPE_PHONE]]];
  }

  if (userIdentity.identifiers[IDENTIFIER_TYPE_EMAIL] != nil) {
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"e" value:userIdentity.identifiers[IDENTIFIER_TYPE_EMAIL]]];
  }

  if (userIdentity.identifiers[IDENTIFIER_TYPE_KLAVIYO_ID] != nil) {
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"kid" value:userIdentity.identifiers[IDENTIFIER_TYPE_KLAVIYO_ID]]];
  }

  if (userIdentity.identifiers[IDENTIFIER_TYPE_SHOPIFY_ID] != nil) {
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"sid" value:userIdentity.identifiers[IDENTIFIER_TYPE_KLAVIYO_ID]]];
  }

  if (userIdentity.identifiers[IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS] != nil) {
    [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"cstm" value:[[self class] getCustomIdentifiersJson:userIdentity]]];
  }

  // Add SDK info just for analytics purposes
  [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"sdkVersion" value:[ATTNAppInfo getSdkVersion]]];
  [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"sdkName" value:[ATTNAppInfo getSdkName]]];

  [components setQueryItems:queryItems];

  return [components string];
}

+ (nonnull NSString *)getCustomIdentifiersJson:(ATTNUserIdentity *)userIdentity {
  @try {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userIdentity.identifiers[IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS]
                                                       options:0 // Do not pretty print the json string
                                                         error:&error];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  } @catch (NSException *exception) {
    NSLog(@"ERROR: Could not parse custom identifiers to json %@", exception);
  }

  return @"{}";
}

@end
