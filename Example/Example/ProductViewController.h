//
//  ProductViewController.h
//  Example
//
//  Created by Wyatt Davis on 1/17/23.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProductViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *addToCartButton;
@property (weak, nonatomic) IBOutlet UIButton *purchaseButton;

- (IBAction)addToCartButtonPressed:(id)sender;

- (IBAction)purchaseButtonPressed:(id)sender;

@end

NS_ASSUME_NONNULL_END
