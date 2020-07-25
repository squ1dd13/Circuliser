#include "BPTRootListController.h"
#import <Preferences/PSSpecifier.h>
#include "SQGraphView.hpp"
#include "SQGraphView.mm"

#define kWidth [[UIApplication sharedApplication] keyWindow].frame.size.width

@protocol PreferencesTableCustomView
- (id)initWithSpecifier:(id)arg1;

@optional
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1;
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 inTableView:(id)arg2;
@end

@interface SQGraphCellView : UITableViewCell <PreferencesTableCustomView> {
    SQGraphView *graph;
}
@end

@implementation SQGraphCellView

- (id)initWithSpecifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	if (self) {
		CGRect frame = CGRectMake(kWidth * 0.05f, 0, kWidth * .9f, 165);

		graph = [[SQGraphView alloc] initWithFrame:frame];
        float values[5] {
            .5f,
            .5f,
            .5f,
            .5f,
            .5f
        };

        graph->color = [UIColor performSelector:@selector(systemBlueColor)];
        [graph setUpPoints:5 withValues:values];

		[self addSubview:graph];
	}
	return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
    return 165.f;
}
@end

@interface BPTVisualizationSettingsController : PSListController {
	NSArray *_actualSpecifiers;
}

@end

/*

<key>cellClass</key>
			<string>SQBetterSliderCell</string>
			<key>textSelector</key>
			<string>textForMultiplierSlider:</string>

*/

@implementation BPTVisualizationSettingsController

-(NSString *)textForPercentageSlider:(NSNumber *)value {
	return [NSString stringWithFormat:@"%.0f%%", [value floatValue]];
}

-(NSString *)textForFPSSlider:(NSNumber *)value {
	return [NSString stringWithFormat:@"%.0f FPS", [value floatValue]];
}

-(NSString *)textForMultiplierSlider:(NSNumber *)value {
	return [NSString stringWithFormat:@"%.1fx", [value floatValue]];
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Visualisation" target:self];
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

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
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
