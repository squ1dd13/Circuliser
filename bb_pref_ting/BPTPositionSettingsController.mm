#include "BPTRootListController.h"
#import <Preferences/PSSpecifier.h>
#include <algorithm>
#include <utility>

#define kWidth [[UIApplication sharedApplication] keyWindow].frame.size.width

@protocol PreferencesTableCustomView
- (id)initWithSpecifier:(id)arg1;

@optional
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1;
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 inTableView:(id)arg2;
@end

@interface SQReallyCoolPositionCell : PSTableCell <PreferencesTableCustomView> {
	float traversableAreaComponent;
}

@property (nonatomic) UIView *roundedSquareView;
@property (nonatomic) UIView *circleView;
@end


@interface BPTPositionSettingsController : PSListController
-(std::pair<UIColor *, UIColor *>)sampleCellColors;
@property (nonatomic) SQReallyCoolPositionCell *poscell;
-(void)animateUpdate;
@end


//bannah
@implementation SQReallyCoolPositionCell

-(BPTPositionSettingsController *)findController {
	return [self valueForKey:@"viewDelegate"] ?: [self valueForKey:@"_viewControllerForAncestor"];
}

- (id)initWithSpecifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	if (self) {
	}

	return self;
}

-(CGRect)frameFromDeviceScreen {
	const float maxHeight = 170.f;

	CGRect screenSize = [[UIScreen mainScreen] bounds];
	
	float scale = maxHeight / screenSize.size.height; //minDimension = std::min(screenSize.size.width, screenSize.size.height);
	return CGRectMake(0, 0, scale * screenSize.size.width, scale * screenSize.size.height);
}

-(void)layoutSubviews {
	[super layoutSubviews];

	bool useDeviceScreen = true;

	std::pair<UIColor *, UIColor *> cols = [[self findController] sampleCellColors];
	UIColor *lineColor = [self.superview valueForKey:@"separatorColor"];
	if(not self.roundedSquareView) {
		[self findController].poscell = self;

		float smallestDimension = std::min(self.frame.size.width, self.frame.size.height);
		CGRect roundedSquareFrame = useDeviceScreen ? [self frameFromDeviceScreen] : CGRectMake(0, 0, smallestDimension * 0.8f, smallestDimension * 0.8f);
		CGPoint roundedSquareCenter = CGPointMake(self.frame.size.width / 2.f, self.frame.size.height / 2.f);

		self.roundedSquareView = [[UIView alloc] initWithFrame:roundedSquareFrame];
		self.roundedSquareView.center = roundedSquareCenter;
		self.roundedSquareView.backgroundColor = cols.first;
		self.roundedSquareView.layer.cornerRadius = (useDeviceScreen ? 0.05f : 0.2f) * smallestDimension;

		UIView *xAxisLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.roundedSquareView.frame.size.width * 0.76f, 1.f)];
		xAxisLine.center = CGPointMake(self.roundedSquareView.frame.size.width / 2.f, self.roundedSquareView.frame.size.height / 2.f);
		xAxisLine.backgroundColor = lineColor;
		[self.roundedSquareView addSubview:xAxisLine];

		UIView *yAxisLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1.f, self.roundedSquareView.frame.size.height * 0.76f)];
		yAxisLine.center = xAxisLine.center;
		yAxisLine.backgroundColor = lineColor;
		[self.roundedSquareView addSubview:yAxisLine];

		traversableAreaComponent = std::min(yAxisLine.frame.size.height, xAxisLine.frame.size.height);

		self.circleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10.f, 10.f)];
		self.circleView.layer.cornerRadius = 5.f;
		self.circleView.backgroundColor = cols.second;
		self.circleView.center = xAxisLine.center;

		[self.roundedSquareView addSubview:self.circleView];

		[self addSubview:self.roundedSquareView];

		[[self findController] animateUpdate];
	}
}

- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
    return 200.f;
}

-(void)updateForPercentageValues:(std::pair<int, int>)percentages {
	double xPercent = double(percentages.first) / 100.;
	double yPercent = double(percentages.second) / 100.;

	CGPoint normalCenter = CGPointMake(self.roundedSquareView.frame.size.width / 2.f, self.roundedSquareView.frame.size.height / 2.f);

	[UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
		self.circleView.center = CGPointMake(normalCenter.x + (xPercent * normalCenter.x), normalCenter.y + (yPercent * normalCenter.y));
    } completion:NULL];
}

@end


@implementation BPTPositionSettingsController

-(PSTableCell *)cellForSpecifierID:(NSString *)specifierID {
	long long index = [self indexOfSpecifierID:specifierID];
	id indexPath = [self indexPathForIndex:index];

	UITableView *table = [self valueForKey:@"_table"];
	return (id)[self tableView:table cellForRowAtIndexPath:indexPath];
}

-(std::pair<UIColor *, UIColor *>)sampleCellColors {
	PSTableCell *cell = [self cellForSpecifierID:@"cposcell"];

	return {[cell backgroundColor], [cell.titleLabel textColor]};
}

-(NSString *)textForPercentageSlider:(NSNumber *)value {
	return [NSString stringWithFormat:@"%.0f%%", [value floatValue]];
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Position" target:self];
	}
[self setValue:@0 forKeyPath:@"_table.separatorStyle"];
	return _specifiers;
}

-(UIColor *)separatorColor {
	return [UIColor clearColor];
}

-(id)readPreferenceValue:(PSSpecifier*)specifier {
	NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
	return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

-(void)animateUpdate {
	/*
	SQIntegerSliderCell *xCell = (id)[self cellForSpecifierID:@"eks"];
	SQIntegerSliderCell *yCell = (id)[self cellForSpecifierID:@"why"];

	((UISlider *)(xCell.control)).continuous = true;
	((UISlider *)(yCell.control)).continuous = true;

	int xPercent = [xCell integerSliderValue];
	int yPercent = [yCell integerSliderValue];
	*/

	//SQReallyCoolPositionCell *rcpc = (id)[self cellForSpecifierID:@"tbo"];
	//[self.poscell updateForPercentageValues:{xPercent, yPercent}];
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
	//[NSObject cancelPreviousPerformRequestsWithTarget:self];
	//[self performSelector:@selector(animateUpdate) withObject:nil afterDelay:0.1f];

	NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
	[settings setObject:value forKey:specifier.properties[@"key"]];
	[settings writeToFile:path atomically:YES];
	CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
	if (notificationName) {
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
	}
}

@end
