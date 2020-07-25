#import <Preferences/PSListController.h>
#include <dlfcn.h>
@import UIKit;
#include <Preferences/PSSliderTableCell.h>

@interface SQIntegerSliderCell : PSSliderTableCell {
	bool _didSwapLabels;
	UILabel *newLabel;
	bool _didAddObservers;
}
-(int)integerSliderValue;
@end

@interface SQBetterSliderCell : PSSliderTableCell {
    bool _didSwapLabels;
    UILabel *newLabel;
    bool _didAddObservers;
}

@end

inline void alert(NSString *title, NSString *content, NSString *dismissButtonStr, UIViewController *preferredVC = NULL) {
    if(!preferredVC) {
        preferredVC = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    }

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:content preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *dismiss = [UIAlertAction actionWithTitle:dismissButtonStr style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:dismiss];
    [preferredVC presentViewController:alert animated:YES completion:nil];
}

@interface BPTRootListController : PSListController

@end
