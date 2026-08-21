//
//  ProductViewController.m
//  Example
//
//  Created by Wyatt Davis on 1/17/23.
//

#import "ProductViewController.h"
#import "ATTNSDKFramework/ATTNSDKFramework-Swift.h"

@interface ProductViewController ()

@end

@implementation ProductViewController
- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  ATTNItem* item = [self buildItem];
  ATTNProductViewEvent* productView = [[ATTNProductViewEvent alloc] initWithItems:@[ item ]];
  productView.deeplink = @"https://mydeeplink.com/products/32432423";

  [[ATTNEventTracker sharedInstance] recordEvent:productView];

  [self showToast:@"Product View event sent" duration:2];
}


- (IBAction)addToCartButtonPressed:(id)sender {
  ATTNItem* item = [self buildItem];
  ATTNAddToCartEvent* addToCart = [[ATTNAddToCartEvent alloc] initWithItems:@[ item ]];

  [[ATTNEventTracker sharedInstance] recordEvent:addToCart];
  [self showToast:@"Add To Cart event sent" duration:2];
}

- (IBAction)addToCartWithDeeplinkButtonPressed:(id)sender {
  ATTNItem* item = [self buildItem];
  ATTNAddToCartEvent* addToCart = [[ATTNAddToCartEvent alloc] initWithItems:@[ item ]];
  addToCart.deeplink = @"https://mydeeplink.com/products/32432423";

  [[ATTNEventTracker sharedInstance] recordEvent:addToCart];
  [self showToast: [NSString stringWithFormat:@"Add To Cart event sent with requestURL(pd): '%@'", addToCart.deeplink] duration:4];
}

- (IBAction)purchaseButtonPressed:(id)sender {
  NSLog(@"Purchase button pressed");

  // Create the Items that were purchased
  ATTNItem* item = [self buildItem];
  // Create the Order
  ATTNOrder* order = [[ATTNOrder alloc] initWithOrderId:@"778899"];
  // Create PurchaseEvent
  ATTNPurchaseEvent* purchase = [[ATTNPurchaseEvent alloc] initWithItems:@[ item ] order:order];

  [[ATTNEventTracker sharedInstance] recordEvent:purchase];

  [self showToast:@"Purchase event sent" duration:2];
}

- (ATTNItem*)buildItem {
  // Build Item with required fields
  ATTNItem* item = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithAmount:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];
  // Add some optional fields
  item.name = @"T-Shirt";
  item.category = @"Tops";
  return item;
}

- (IBAction)customEventButtonPressed:(id)sender {
  ATTNCustomEvent* customEvent = [[ATTNCustomEvent alloc] initWithType:@"Added to Wishlist" properties:@{@"wishlistName" : @"Gift Ideas"}];

  [[ATTNEventTracker sharedInstance] recordEvent:customEvent];

  [self showToast:@"Custom event sent" duration:2];
}

- (void)showToast:(NSString*)message duration:(int)duration {
  UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
                                                                 message:message
                                                          preferredStyle:UIAlertControllerStyleAlert];

  [self presentViewController:alert animated:YES completion:nil];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    [alert dismissViewControllerAnimated:YES completion:nil];
  });
}

@end
