#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "ATTNAddToCartEvent.h"
#import "ATTNAPI.h"
#import "ATTNCart.h"
#import "ATTNEvent.h"
#import "ATTNEventTracker.h"
#import "ATTNItem.h"
#import "ATTNOrder.h"
#import "ATTNParameterValidation.h"
#import "ATTNPersistentStorage.h"
#import "ATTNPrice.h"
#import "ATTNProductViewEvent.h"
#import "ATTNPurchaseEvent.h"
#import "ATTNSDK.h"
#import "ATTNUserIdentity.h"
#import "ATTNVisitorService.h"

FOUNDATION_EXPORT double attentive_ios_sdkVersionNumber;
FOUNDATION_EXPORT const unsigned char attentive_ios_sdkVersionString[];

