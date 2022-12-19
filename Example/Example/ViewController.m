#import "ViewController.h"
#import "ImportAttentiveSDK.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *creativeButton;
@property (weak, nonatomic) IBOutlet UIButton *sendIdentifiersButton;
@property (weak, nonatomic) IBOutlet UIButton *clearUserButton;
@property (weak, nonatomic) IBOutlet UIButton *purchaseButton;
@end


@implementation ViewController {
    NSDictionary* _userIdentifiers;
}

ATTNSDK *sdk;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGray3Color];
    
    // Intialize the Attentive SDK. Replace with your Attentive domain to test
    // with your Attentive account.
    // This only has to be done once per application lifecycle so you can do
    // this in a singleton class rather than each time a view loads.
    sdk = [[ATTNSDK alloc] initWithDomain:@"games" mode:@"production"];
    [ATTNEventTracker setupWithSdk:sdk];
    
    // Register the current user with the Attentive SDK by calling the `identify` method. Each identifier is optional, but the more identifiers you provide the better the Attentive SDK will function.
    _userIdentifiers = @{ IDENTIFIER_TYPE_PHONE: @"+14156667777",
                          IDENTIFIER_TYPE_EMAIL: @"someemail@email.com",
                          IDENTIFIER_TYPE_CLIENT_USER_ID: @"APP_USER_ID",
                          IDENTIFIER_TYPE_SHOPIFY_ID: @"207119551",
                          IDENTIFIER_TYPE_KLAVIYO_ID: @"555555",
                          IDENTIFIER_TYPE_CUSTOM_IDENTIFIERS: @{@"customId": @"customIdValue"}
    };
    [sdk identify:_userIdentifiers];
}

- (IBAction)creativeButtonPress:(id)sender {
    // Clear cookies to avoid Creative filtering during testing. Do not clear
    // cookies if you want to test Creative fatigue and filtering.
    [self clearCookies];
    
    // Display the creative.
    [sdk trigger:self.view];
}

- (IBAction)sendIdentifiersButtonPress:(id)sender {
    [sdk identify:_userIdentifiers];
}

- (void)clearCookies {
    NSLog(@"Clearing cookies!");
    NSSet *websiteDataTypes = [NSSet setWithArray:@[WKWebsiteDataTypeCookies]];
    NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                               modifiedSince:dateFrom
                                           completionHandler:^() {
        NSLog(@"Cleared cookies!");
    }];
}

- (IBAction)clearUserButtonPressed:(id)sender {
    [sdk clearUser];
}

- (IBAction)purchaseButtonPressed:(id)sender {
    NSLog(@"Purchase button pressed");
    
    // Create the Items that were purchased
    ATTNItem* item = [[ATTNItem alloc] initWithProductId:@"222" productVariantId:@"55555" price:[[ATTNPrice alloc] initWithPrice:[[NSDecimalNumber alloc] initWithString:@"15.99"] currency:@"USD"]];
    // Create the Order
    ATTNOrder* order = [[ATTNOrder alloc] initWithOrderId:@"778899"];
    // Create PurchaseEvent
    ATTNPurchaseEvent* purchase = [[ATTNPurchaseEvent alloc] initWithItems:@[item] order:order];
    
    [[ATTNEventTracker sharedInstance] recordEvent:purchase];
}

@end
