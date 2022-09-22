#import "ViewController.h"
// Use the Creative package from your local attentive-ios-sdk folder
#import "../../Creative/ATTNSDK.h"
// Use the published version of the attentive-ios-sdk
// #import "attentive_ios_sdk/attentive-ios-sdk-umbrella.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *creativeButton;
@end


@implementation ViewController

ATTNSDK *sdk;


- (void)viewDidLoad {
    [super viewDidLoad];
    // Intialize the Attentive SDK. Replace with your Attentive domain to test
    // with your Attentive account.
    // This only has to be done once per application lifecycle so you can do
    // this in a singleton class rather than each time a view loads.
    sdk = [[ATTNSDK alloc] initWithDomain:@"YOUR_ATTENTIVE_DOMAIN"];
    
    // Register the current user with the Attentive SDK. Replace "APP_USER_ID"
    // with the current user's ID. You must register a user ID before calling
    // `trigger` on a Creative
    [sdk identify:@"APP_USER_ID"];
}

- (IBAction)creativeButtonPress:(id)sender {
    // Clear cookies to avoid Creative filtering during testing. Do not clear
    // cookies if you want to test Creative fatigue and filtering.
    [self clearCookies];
    
    // Display the creative.
    [sdk trigger:self.view];
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
@end
