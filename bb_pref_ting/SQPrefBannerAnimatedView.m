// i thought it would look cool ok

#import "SQPrefBannerAnimatedView.h"
#import <QuartzCore/QuartzCore.h>

CGRect CGRectMakeRound(CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
    return CGRectMake(round(x), round(y), round(w), round(h));
}

CGPoint CGPointMakeRound(CGFloat x, CGFloat y) {
    return CGPointMake(round(x), round(y));
}

static UIColor *fgcol(UIColor *col) {
    CGFloat r, g, b, a;
    [col getRed:&r green:&g blue:&b alpha:&a];

    r *= 255.f;
    g *= 255.f;
    b *= 255.f;

    return 255.f - (r * .299f + g * .587f + b * .114f) < 105.f ? [UIColor blackColor] : [UIColor whiteColor];
}

@interface SQPrefBannerAnimatedView ()

@end

@implementation SQPrefBannerAnimatedView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frameRect {
    self = [super initWithFrame:frameRect];
    
    if(self) {
        //[self setupLayers];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    
    if(self) {
        //[self setupLayers];
    }
    
    return self;
}

- (void)startAnimation {
    [self setupLayers];
}

- (BOOL)isFlipped {
    return YES;
}

#pragma mark - Setup Layers

- (void)setupLayers {
    UIColor *backgroundColor = [UIColor colorWithRed:0.940995 green:0.940995 blue:0.940995 alpha:1];
    if([[UIColor class] respondsToSelector:@selector(secondarySystemGroupedBackgroundColor)]) {
        backgroundColor = [[UIColor class] performSelector:@selector(secondarySystemGroupedBackgroundColor)];
    } else {
        backgroundColor = self.superview.superview.backgroundColor;
    }

    UIColor *borderColor = [UIColor clearColor];//colorWithRed:0.515047 green:0.0255 blue:0.85 alpha:0];
    UIColor *borderColor1 = [UIColor clearColor];//olorWithRed:0.795254 green:0.795254 blue:0.795254 alpha:0];
    UIColor *foregroundColor = fgcol(backgroundColor);//UIColor.blackColor;
    
    UIFont *systemFontFont = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];//systemFontOfSize:32.f weight:UIFontWeightSemibold];
    UIFont *systemFontFont1 = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    
    CALayer *layerLayer = [CALayer layer];
    layerLayer.name = @"Layer";
    layerLayer.bounds = CGRectMakeRound(0, 0, 0.4f * self.frame.size.height, 0.4f * self.frame.size.height);
    layerLayer.position = CGPointMakeRound(self.frame.size.width / 2.f, self.frame.size.height / 2.f);
    layerLayer.contentsGravity = kCAGravityCenter;
    layerLayer.backgroundColor = backgroundColor.CGColor;
    layerLayer.cornerRadius = layerLayer.bounds.size.height / 2.f;
    layerLayer.borderWidth = 1;
    layerLayer.borderColor = borderColor.CGColor;
    layerLayer.shadowOffset = CGSizeMake(0, 1);
    layerLayer.fillMode = kCAFillModeForwards;
    layerLayer.sublayerTransform = (CATransform3D){.m11 = -1, .m12 = 0, .m13 = 0, .m14 = 0, .m21 = 0, .m22 = -1, .m23 = 0, .m24 = 0, .m31 = 0, .m32 = 0, .m33 = 1, .m34 = 0, .m41 = 0, .m42 = 0, .m43 = 0, .m44 = 1};
    
    CABasicAnimation *boundsSizeWidthAnimation = [CABasicAnimation animation];
    boundsSizeWidthAnimation.beginTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] + 0.000001;
    boundsSizeWidthAnimation.duration = 0.5;
    boundsSizeWidthAnimation.fillMode = kCAFillModeForwards;
    boundsSizeWidthAnimation.removedOnCompletion = NO;
    boundsSizeWidthAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.0903:0.004294:0.451398:0.916225];
    boundsSizeWidthAnimation.keyPath = @"bounds.size.width";
    boundsSizeWidthAnimation.toValue = @(round(self.frame.size.height / 2.f));
    boundsSizeWidthAnimation.fromValue = @(0);
    
    [layerLayer addAnimation:boundsSizeWidthAnimation forKey:@"boundsSizeWidthAnimation"];
    
    CABasicAnimation *boundsSizeWidthAnimation1 = [CABasicAnimation animation];
    boundsSizeWidthAnimation1.beginTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] + 0.5;
    boundsSizeWidthAnimation1.duration = 0.5;
    boundsSizeWidthAnimation1.fillMode = kCAFillModeForwards;
    boundsSizeWidthAnimation1.removedOnCompletion = NO;
    boundsSizeWidthAnimation1.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.0903:0.004294:0.451398:0.916225];
    boundsSizeWidthAnimation1.keyPath = @"bounds.size.width";
    boundsSizeWidthAnimation1.toValue = @(self.frame.size.width);
    
    [layerLayer addAnimation:boundsSizeWidthAnimation1 forKey:@"boundsSizeWidthAnimation1"];
    
    CABasicAnimation *boundsSizeHeightAnimation = [CABasicAnimation animation];
    boundsSizeHeightAnimation.beginTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] + 0.000001;
    boundsSizeHeightAnimation.duration = 0.5;
    boundsSizeHeightAnimation.fillMode = kCAFillModeForwards;
    boundsSizeHeightAnimation.removedOnCompletion = NO;
    boundsSizeHeightAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.0903:0.004294:0.451398:0.916225];
    boundsSizeHeightAnimation.keyPath = @"bounds.size.height";
    boundsSizeHeightAnimation.toValue = @(round(self.frame.size.height / 2.f));
    boundsSizeHeightAnimation.fromValue = @(0);
    
    [layerLayer addAnimation:boundsSizeHeightAnimation forKey:@"boundsSizeHeightAnimation"];
    
    CABasicAnimation *boundsSizeHeightAnimation1 = [CABasicAnimation animation];
    boundsSizeHeightAnimation1.beginTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] + 0.5;
    boundsSizeHeightAnimation1.duration = 0.5;
    boundsSizeHeightAnimation1.fillMode = kCAFillModeForwards;
    boundsSizeHeightAnimation1.removedOnCompletion = NO;
    boundsSizeHeightAnimation1.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.0903:0.004294:0.451398:0.916225];
    boundsSizeHeightAnimation1.keyPath = @"bounds.size.height";
    boundsSizeHeightAnimation1.toValue = @(self.frame.size.height);
    
    [layerLayer addAnimation:boundsSizeHeightAnimation1 forKey:@"boundsSizeHeightAnimation1"];
    
    CABasicAnimation *cornerRadiusAnimation = [CABasicAnimation animation];
    cornerRadiusAnimation.beginTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] + 0.000001;
    cornerRadiusAnimation.duration = 0.5;
    cornerRadiusAnimation.fillMode = kCAFillModeForwards;
    cornerRadiusAnimation.removedOnCompletion = NO;
    cornerRadiusAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.0903:0.004294:0.451398:0.916225];
    cornerRadiusAnimation.keyPath = @"cornerRadius";
    cornerRadiusAnimation.toValue = @(round(self.frame.size.height / 4.f));
    cornerRadiusAnimation.fromValue = @(0);
    
    [layerLayer addAnimation:cornerRadiusAnimation forKey:@"cornerRadiusAnimation"];
    
    CABasicAnimation *cornerRadiusAnimation1 = [CABasicAnimation animation];
    cornerRadiusAnimation1.beginTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] + 0.5;
    cornerRadiusAnimation1.duration = 0.5;
    cornerRadiusAnimation1.fillMode = kCAFillModeForwards;
    cornerRadiusAnimation1.removedOnCompletion = NO;
    cornerRadiusAnimation1.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.0903:0.004294:0.451398:0.916225];
    cornerRadiusAnimation1.keyPath = @"cornerRadius";
    cornerRadiusAnimation1.toValue = @(0);
    
    [layerLayer addAnimation:cornerRadiusAnimation1 forKey:@"cornerRadiusAnimation1"];
    
    [self.layer addSublayer:layerLayer];

    CATextLayer *textLayer = [CATextLayer layer];
    textLayer.name = @"Text";
    textLayer.bounds = CGRectMakeRound(0, 0, self.frame.size.width, 1.2f * [systemFontFont pointSize]);
    textLayer.position = CGPointMakeRound(self.frame.size.width / 2.f, self.frame.size.height / 2.f - (textLayer.bounds.size.height));
    textLayer.contentsGravity = kCAGravityCenter;
    textLayer.opacity = 0;
    textLayer.fontSize = [systemFontFont pointSize];
    textLayer.borderColor = borderColor1.CGColor;
    textLayer.shadowOffset = CGSizeMake(0, 1);
    textLayer.magnificationFilter = kCAFilterNearest;
    textLayer.needsDisplayOnBoundsChange = YES;
    textLayer.contentsScale = [[UIScreen mainScreen] scale];
    textLayer.fillMode = kCAFillModeForwards;
    textLayer.transform = (CATransform3D){.m11 = 1, .m12 = 0, .m13 = 0, .m14 = 0, .m21 = 0, .m22 = 1, .m23 = 0, .m24 = 0, .m31 = -0, .m32 = -0, .m33 = 1, .m34 = 0, .m41 = 0, .m42 = 0, .m43 = 0, .m44 = 1};
    
    CABasicAnimation *opacityAnimation = [CABasicAnimation animation];
    opacityAnimation.beginTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] + 1;
    opacityAnimation.duration = 0.5;
    opacityAnimation.fillMode = kCAFillModeForwards;
    opacityAnimation.removedOnCompletion = NO;
    opacityAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    opacityAnimation.keyPath = @"opacity";
    opacityAnimation.toValue = @(1);
    
    [textLayer addAnimation:opacityAnimation forKey:@"opacityAnimation"];
    textLayer.string = @"BounceBass";
    
    textLayer.foregroundColor = foregroundColor.CGColor;
    textLayer.font = (__bridge CFTypeRef)(systemFontFont);
    textLayer.wrapped = YES;
    textLayer.alignmentMode = kCAAlignmentCenter;
    
    [self.layer addSublayer:textLayer];

    CATextLayer *textLayer1 = [CATextLayer layer];
    textLayer1.name = @"Text";
    textLayer1.bounds = CGRectMakeRound(0, 0, self.frame.size.width, 1.4f * [systemFontFont1 pointSize]);
    textLayer1.position = CGPointMakeRound(self.frame.size.width / 2.f, self.frame.size.height - (textLayer1.bounds.size.height / 1.5f));
    textLayer1.contentsGravity = kCAGravityCenter;
    textLayer1.opacity = 0;
    textLayer1.borderColor = borderColor1.CGColor;
    textLayer1.shadowOffset = CGSizeMake(0, 1);
    textLayer1.magnificationFilter = kCAFilterNearest;
    textLayer1.needsDisplayOnBoundsChange = YES;
    textLayer1.fillMode = kCAFillModeForwards;
    textLayer1.contentsScale = [[UIScreen mainScreen] scale];
    textLayer1.transform = (CATransform3D){.m11 = 1, .m12 = 0, .m13 = 0, .m14 = 0, .m21 = 0, .m22 = 1, .m23 = 0, .m24 = 0, .m31 = -0, .m32 = -0, .m33 = 1, .m34 = 0, .m41 = 0, .m42 = 0, .m43 = 0, .m44 = 1};

    CABasicAnimation *opacityAnimation1 = [CABasicAnimation animation];
    opacityAnimation1.beginTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] + 1.25;
    opacityAnimation1.duration = 0.5;
    opacityAnimation1.fillMode = kCAFillModeForwards;
    opacityAnimation1.removedOnCompletion = NO;
    opacityAnimation1.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    opacityAnimation1.keyPath = @"opacity";
    opacityAnimation1.toValue = @(1);
    
    [textLayer1 addAnimation:opacityAnimation1 forKey:@"opacityAnimation1"];
    textLayer1.string = @"© 2020 Squ1dd13";
    textLayer1.fontSize = [systemFontFont1 pointSize];
    textLayer1.foregroundColor = foregroundColor.CGColor;
    textLayer1.font = (__bridge CFTypeRef)(systemFontFont1);
    textLayer1.wrapped = YES;
    textLayer1.alignmentMode = kCAAlignmentCenter;
    
    [self.layer addSublayer:textLayer1];
    textLayer1.masksToBounds = 0;
    textLayer.masksToBounds = 0;
}

@end
