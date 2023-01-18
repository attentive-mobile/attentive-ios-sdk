//
//  ProductViewController.m
//  Example
//
//  Created by Wyatt Davis on 1/17/23.
//

#import "ProductViewController.h"
#import "ImportAttentiveSDK.h"

@interface ProductViewController ()

@end

@implementation ProductViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    ATTNItem* item = [self buildItem];
    ATTNProductViewEvent* productView = [[ATTNProductViewEvent alloc] initWithItems:@[item]];
    
    [[ATTNEventTracker sharedInstance] recordEvent:productView];
    [self showToast:@"Product View event sent"];
}

- (IBAction)addToCartButtonPressed:(id)sender {
    ATTNItem* item = [self buildItem];
    ATTNAddToCartEvent* addToCart = [[ATTNAddToCartEvent alloc] initWithItems:@[item]];
    
    [[ATTNEventTracker sharedInstance] recordEvent:addToCart];
    [self showToast:@"Add To Cart event sent"];
}

- (IBAction)purchaseButtonPressed:(id)sender {
    NSLog(@"Purchase button pressed");
    
    // Create the Items that were purchased
    ATTNItem* item = [self buildItem];
    // Create the Order
    ATTNOrder* order = [[ATTNOrder alloc] initWithOrderId:@"778899"];
    // Create PurchaseEvent
    ATTNPurchaseEvent* purchase = [[ATTNPurchaseEvent alloc] initWithItems:@[item] order:order];
    
    [[ATTNEventTracker sharedInstance] recordEvent:purchase];
    
    [self showToast:@"Purchase event sent"];
}

- (ATTNItem*)buildItem {
    // Build Item with required fields
    ATTNItem* item = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];
    // Add some optional fields
    item.name = @"T-Shirt";
    item.category = @"Tops";
    return item;
}

- (void)showToast:(NSString*)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [self presentViewController:alert animated:YES completion:nil];

    int duration = 1; // duration in seconds

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
