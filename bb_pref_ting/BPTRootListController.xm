#include "BPTRootListController.h"
#import <Preferences/PSSpecifier.h>
#include <cmath>
#include <MRYIPCCenter.h>
#include "../NSTask.h"

#import <objc/runtime.h>

@implementation SQIntegerSliderCell

- (void)pushTransition:(CFTimeInterval)duration reverseDirection:(bool)rev {
    CATransition *animation = [CATransition new];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.type = kCATransitionPush;
    animation.subtype = rev ? kCATransitionFromBottom : kCATransitionFromTop;

    animation.duration = duration;
    [newLabel.layer addAnimation:animation forKey:kCATransitionPush];
}

-(void)repositionLabel {
	if(not newLabel) return;

	[newLabel setTranslatesAutoresizingMaskIntoConstraints:false];

	UISlider *slider = (UISlider *)self.control;

	UIView *maxTrackClipView = [slider valueForKey:@"_maxTrackClipView"];
	if(not maxTrackClipView) return;

	float minX = maxTrackClipView.frame.origin.x + maxTrackClipView.frame.size.width;
	float maxX = self.frame.size.width - slider.frame.origin.x;

	if(newLabel) {
		CGRect frame = newLabel.frame;
		frame.origin.x = ((minX + maxX - frame.size.width) / 2.f) ;

		newLabel.frame = frame;
	}
}

-(UIViewController *)viewController {
	return [self valueForKey:@"viewDelegate"] ?: [self valueForKey:@"_viewControllerForAncestor"];
}

-(NSString *)basicTextForValue:(NSNumber *)value {
	return [NSString stringWithFormat:@"%d", int([value floatValue])];
}

-(NSString *)textForValue:(NSNumber *)value {
	id textTarget = self.specifier.properties[@"textSelector"] ? [self viewController] : self;
	SEL textSelector = NSSelectorFromString(self.specifier.properties[@"textSelector"] ?: @"basicTextForValue:");

	#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [textTarget performSelector:textSelector withObject:value];
#pragma clang diagnostic pop
	
}

-(void)setValue:(NSNumber *)value {
	[super setValue:@(int([value floatValue]))];

	[self repositionLabel];
}

-(void)layoutSubviews {
	[super layoutSubviews];

	if(not _didSwapLabels) {
		UILabel *oldLabel = self.control.subviews[0];
		if(not oldLabel) return;

		newLabel = [[UILabel alloc] initWithFrame:oldLabel.frame];
		newLabel.font = oldLabel.font;
		newLabel.textColor = oldLabel.textColor;
		newLabel.textAlignment = NSTextAlignmentCenter;
		newLabel.text = [self textForValue:@(((UISlider *)(self.control)).value)];//[NSString stringWithFormat:@"%d", int(((UISlider *)(self.control)).value)];
		newLabel.lineBreakMode = NSLineBreakByClipping;

		[self.control.subviews[0] setHidden:true];
		[self.control addSubview:newLabel];

		[newLabel sizeToFit];
		[self repositionLabel];

		[self valueUpdated:(UISlider *)self.control forEvent:nullptr];

		_didSwapLabels = true;
	}

	if(true) {//not _didAddObservers) {
		((UISlider *)(self.control)).continuous = true;
		[self.control addTarget:self action:@selector(valueUpdated:forEvent:) forControlEvents:UIControlEventValueChanged];
		[self.control addTarget:self action:@selector(valueUpdated:forEvent:) forControlEvents:UIControlEventTouchUpInside bitor UIControlEventTouchUpOutside bitor UIControlEventTouchCancel bitor UIControlEventEditingDidEnd | UIControlEventTouchDragExit |
               UIControlEventTouchDragOutside];
		_didAddObservers = true;
	}

	[self repositionLabel];
}

-(void)valueUpdated:(UISlider *)sender forEvent:(id)evnt {
	sender.value = float(int(sender.value));

	newLabel.text = [self textForValue:@(((UISlider *)(self.control)).value)];
    [newLabel sizeToFit];
    [self repositionLabel];
}

-(NSNumber *)controlValue {
	NSNumber *orig = [super controlValue];
	return @(int([orig floatValue]));
}

-(int)integerSliderValue {
	return int(((UISlider *)(self.control)).value);
}

-(void)layoutIfNeeded {
	[super layoutIfNeeded];

	[self repositionLabel];
}

@end

@implementation SQBetterSliderCell

-(float)roundValueForValue:(float)value {
	return std::round(value * 10.f) / 10.f;
}

- (void)pushTransition:(CFTimeInterval)duration reverseDirection:(bool)rev {
    CATransition *animation = [CATransition new];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.type = kCATransitionPush;
    animation.subtype = rev ? kCATransitionFromBottom : kCATransitionFromTop;

    animation.duration = duration;
    [newLabel.layer addAnimation:animation forKey:kCATransitionPush];
}

-(void)repositionLabel {
	if(not newLabel) return;

	[newLabel setTranslatesAutoresizingMaskIntoConstraints:false];

	UISlider *slider = (UISlider *)self.control;

	UIView *maxTrackClipView = [slider valueForKey:@"_maxTrackClipView"];
	if(not maxTrackClipView) return;

	float minX = maxTrackClipView.frame.origin.x + maxTrackClipView.frame.size.width;
	float maxX = self.frame.size.width - slider.frame.origin.x;

	if(newLabel) {
		CGRect frame = newLabel.frame;
		frame.origin.x = ((minX + maxX - frame.size.width) / 2.f) ;

		newLabel.frame = frame;
	}
}

-(UIViewController *)viewController {
	return [self valueForKey:@"viewDelegate"] ?: [self valueForKey:@"_viewControllerForAncestor"];
}

-(NSString *)basicTextForValue:(NSNumber *)value {
	return [NSString stringWithFormat:@"%f", [value floatValue]];
}

-(NSString *)textForValue:(NSNumber *)value {
	id textTarget = self.specifier.properties[@"textSelector"] ? [self viewController] : self;
	SEL textSelector = NSSelectorFromString(self.specifier.properties[@"textSelector"] ?: @"basicTextForValue:");

	#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [textTarget performSelector:textSelector withObject:value];
#pragma clang diagnostic pop
	
}

-(void)setValue:(NSNumber *)value {
	[super setValue:@([self roundValueForValue:[value floatValue]])];

	[self repositionLabel];
}

-(void)layoutSubviews {
	[super layoutSubviews];

	if(not _didSwapLabels) {
		UILabel *oldLabel = self.control.subviews[0];
		if(not oldLabel) return;

		newLabel = [[UILabel alloc] initWithFrame:oldLabel.frame];
		newLabel.font = oldLabel.font;
		newLabel.textColor = oldLabel.textColor;
		newLabel.textAlignment = NSTextAlignmentCenter;
		newLabel.text = [self textForValue:@(((UISlider *)(self.control)).value)];//[NSString stringWithFormat:@"%d", int(((UISlider *)(self.control)).value)];
		newLabel.lineBreakMode = NSLineBreakByClipping;

		[self.control.subviews[0] setHidden:true];
		[self.control addSubview:newLabel];

		[newLabel sizeToFit];
		[self repositionLabel];

		[self valueUpdated:(UISlider *)self.control forEvent:nullptr];

		_didSwapLabels = true;
	}

	if(true) {//not _didAddObservers) {
		((UISlider *)(self.control)).continuous = true;
		[self.control addTarget:self action:@selector(valueUpdated:forEvent:) forControlEvents:UIControlEventValueChanged];
		[self.control addTarget:self action:@selector(valueUpdated:forEvent:) forControlEvents:UIControlEventTouchUpInside bitor UIControlEventTouchUpOutside bitor UIControlEventTouchCancel bitor UIControlEventEditingDidEnd | UIControlEventTouchDragExit |
               UIControlEventTouchDragOutside];
		_didAddObservers = true;
	}

	[self repositionLabel];
}

-(void)valueUpdated:(UISlider *)sender forEvent:(id)evnt {
	sender.value = [self roundValueForValue:sender.value];//float(sender.value);

	newLabel.text = [self textForValue:@(sender.value)];
    [newLabel sizeToFit];
    [self repositionLabel];
}

-(NSNumber *)controlValue {
	NSNumber *orig = [super controlValue];
	return @([self roundValueForValue:[orig floatValue]]);
}

-(void)layoutIfNeeded {
	[super layoutIfNeeded];

	[self repositionLabel];
}

@end

#define kWidth [[UIApplication sharedApplication] keyWindow].frame.size.width

#include "SQPrefBannerAnimatedView.h"

@protocol PreferencesTableCustomView
- (id)initWithSpecifier:(id)arg1;

@optional
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1;
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 inTableView:(id)arg2;
@end

@interface SQPrefBannerView : UITableViewCell <PreferencesTableCustomView> {
    SQPrefBannerAnimatedView *animView;
}
@end

#include "Animation.mm"

//banner
@implementation SQPrefBannerView

- (id)initWithSpecifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	if (self) {
		CGRect frame = CGRectMake(0, 0, kWidth, 80);

		animView = [[SQPrefBannerAnimatedView alloc] initWithFrame:frame];
		[self addSubview:animView];

		[animView startAnimation];
	}

	return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
    return 80.0f;
}

@end

inline UIColor *foregroundColor(UIColor *col) {
	CGFloat r, g, b, a;
	[col getRed:&r green:&g blue:&b alpha:&a];

	r *= 255.f;
	g *= 255.f;
	b *= 255.f;

	return 255.f - (r * .299f + g * .587f + b * .114f) < 105.f ? [UIColor blackColor] : [UIColor whiteColor];
}

@implementation UIColor (LightAndDark)

- (UIColor *)lighterColor {
    CGFloat h, s, b, a;
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a])
        return [UIColor colorWithHue:h
                          saturation:s
                          brightness:MIN(b * 1.3, 1.0)
                               alpha:a];
    return nil;
}

- (UIColor *)darkerColor {
    CGFloat h, s, b, a;
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a])
        return [UIColor colorWithHue:h
                          saturation:s
                          brightness:b * 0.75
                               alpha:a];
    return nil;
}
@end

inline void postNotification(const char *name, id object = nil) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@(name) object:object];
}

#include <AVFoundation/AVFoundation.h>
@implementation BPTRootListController

-(NSArray *)specifiers {
	if(!dlopen("/usr/lib/libinky.dylib", RTLD_LAZY)) {
		alert(@"Colour Picker Not Available", @"The colour picker library could not be loaded. Colour options will not be available.", @"OK");
	}
    

	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	[self setValue:@0 forKeyPath:@"_table.separatorStyle"];

	return _specifiers;
}

-(id)readPreferenceValue:(PSSpecifier*)specifier {

	NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];

	id value = (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
	
	return value;
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	if(specifier.properties[@"id"] and [specifier.properties[@"id"] isEqualToString:@"sld"]) {
		value = @(int([value floatValue]));
	}

	NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
	[settings setObject:value forKey:specifier.properties[@"key"]];
	[settings writeToFile:path atomically:YES];
	CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
	if(notificationName) {
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
	}
}

-(void)applyChanges {
	[self setPreferenceValue:[self readPreferenceValue:_specifiers[0]] specifier:_specifiers[0]];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.squ1dd13.bb_pref_ting.prefschanged"), nullptr, nullptr, 0);
}

-(PSTableCell *)cellForSpecifierID:(NSString *)specifierID {
	long long index = [self indexOfSpecifierID:specifierID];
	id indexPath = [self indexPathForIndex:index];

	UITableView *table = [self valueForKey:@"_table"];
	return (id)[self tableView:table cellForRowAtIndexPath:indexPath];
}

-(void)hackyFadeOutAudio {
	NSURL *soundURL = [NSURL fileURLWithPath:@"/System/Library/Audio/UISounds/ussd.caf"];

	AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:nil];
	player.numberOfLoops = -1;
	player.volume = 0.1f;

	[player play];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    [self hackyFadeOutAudio];

    NSTask *task = [[NSTask alloc] init];

    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[ @"-c", @"/usr/bin/killall mediaserverd && /usr/bin/sbreload" ]];
    [task launch];
}

-(void)reloadThings {
	PSTableCell *cell = [self cellForSpecifierID:@"r e s p r i n g"];

	UIView *windowView = (id)([[[UIApplication sharedApplication] windows] lastObject].rootViewController.view);
	if(not windowView) return;

	CGRect converted = [cell.superview convertRect:cell.frame toView:windowView];

	UIView *fakeCellView = [[UIView alloc] initWithFrame:converted];

	bool makeDarker = [foregroundColor(cell.backgroundColor) isEqual:[UIColor blackColor]];

	fakeCellView.backgroundColor = makeDarker ? [[[cell.backgroundColor darkerColor] darkerColor] darkerColor] : [[[cell.backgroundColor lighterColor] lighterColor] lighterColor];
	[windowView addSubview:fakeCellView];

	animateViewToFillScreen(fakeCellView, self);
}

-(UIColor *)separatorColor {
	return [UIColor clearColor];
}

@end
