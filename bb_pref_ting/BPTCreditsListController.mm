#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListController.h>
#include "BPTRootListController.h"
#include <PreferencesUI/PSUIAppleAccountCell.h>

// I think this category came from SO but I can't find the link.
// Anyway, thanks to whoever wrote it.

@implementation UIImage (Circle)

+(UIImage *)circularScaleAndCropImage:(UIImage *)image frame:(CGRect)frame {
    // This function returns a newImage, based on image, that has been:
    // - scaled to fit in (CGRect) rect
    // - and cropped within a circle of radius: rectWidth/2
    
    //Create the bitmap graphics context
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(frame.size.width, frame.size.height), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //Get the width and heights
    CGFloat imageWidth = image.size.width;
    CGFloat imageHeight = image.size.height;
    CGFloat rectWidth = frame.size.width;
    CGFloat rectHeight = frame.size.height;
    
    //Calculate the scale factor
    CGFloat scaleFactorX = rectWidth/imageWidth;
    CGFloat scaleFactorY = rectHeight/imageHeight;
    
    //Calculate the centre of the circle
    CGFloat imageCentreX = rectWidth/2;
    CGFloat imageCentreY = rectHeight/2;
    
    // Create and CLIP to a CIRCULAR Path
    // (This could be replaced with any closed path if you want a different shaped clip)
    CGFloat radius = rectWidth/2;
    CGContextBeginPath (context);
    CGContextAddArc (context, imageCentreX, imageCentreY, radius, 0, 2*M_PI, 0);
    CGContextClosePath (context);
    CGContextClip (context);
    
    //Set the SCALE factor for the graphics context
    //All future draw calls will be scaled by this factor
    CGContextScaleCTM (context, scaleFactorX, scaleFactorY);
    
    // Draw the IMAGE
    CGRect myRect = CGRectMake(0, 0, imageWidth, imageHeight);
    [image drawInRect:myRect];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+(UIImage *)imageByCroppingImage:(UIImage *)image toSize:(CGSize)size {
    double newCropWidth, newCropHeight;

    if(image.size.width < image.size.height){
         if (image.size.width < size.width) {
                 newCropWidth = size.width;
          }
          else {
                 newCropWidth = image.size.width;
          }
          newCropHeight = (newCropWidth * size.height)/size.width;
    } else {
          if (image.size.height < size.height) {
                newCropHeight = size.height;
          }
          else {
                newCropHeight = image.size.height;
          }
          newCropWidth = (newCropHeight * size.width)/size.height;
    }

    double x = image.size.width/2.0 - newCropWidth/2.0;
    double y = image.size.height/2.0 - newCropHeight/2.0;

    CGRect cropRect = CGRectMake(x, y, newCropWidth, newCropHeight);
    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);

    UIImage *cropped = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);

    return cropped;
}

@end

@interface BPTCreditsListController : PSListController {
	UIImage *_twitterImage;
}
@end

@implementation BPTCreditsListController

-(NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Credits" target:self];

		for(PSSpecifier *specifier in _specifiers) {
			if([specifier.properties[@"id"] isEqualToString:@"twitter"]) {
				if(not _twitterImage) {
                    // Causes a delay when entering the credits page (obviously...).
                    // Who looks at the credits anyway?
					UIImage *squareImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://squ1dd13.github.io/pfp1.png"]]];
					_twitterImage = [UIImage circularScaleAndCropImage:[UIImage imageByCroppingImage:squareImage toSize:CGSizeMake(60, 60)] frame:CGRectMake(0, 0, 60, 60)];
				}

				specifier.properties[@"iconImage"] = _twitterImage;
			}
		}
	}

	return _specifiers;
}

-(void)openTwitter:(PSSpecifier *)specifier {
	NSString *name = specifier.properties[@"accountName"];

	if(not name) {
		alert(@"Error", @"There was an error getting the account link.", @"OK");
		return;
	}

	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://twitter.com/%@", name]] options:@{} completionHandler:nil];
}

@end