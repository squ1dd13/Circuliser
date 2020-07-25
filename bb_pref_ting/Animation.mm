inline void animateViewToFillScreen(UIView *view, id delegate) {
    // This is 100% important.

    UIColor *color = UIColor.blackColor;

    CALayer *cellLayerLayer = view.layer;

    cellLayerLayer.contentsGravity = kCAGravityCenter;
    cellLayerLayer.allowsEdgeAntialiasing = YES;
    cellLayerLayer.allowsGroupOpacity = YES;
    cellLayerLayer.fillMode = kCAFillModeForwards;

    CGFloat layerDimension = MIN(0.112f * UIScreen.mainScreen.bounds.size.width, cellLayerLayer.bounds.size.height / 2.f);
    
    CABasicAnimation *boundsAnimation = [CABasicAnimation animation];
    boundsAnimation.beginTime = [view.layer convertTime: CACurrentMediaTime() fromLayer: nil] + 0.000001;
    boundsAnimation.duration = 0.5;
    boundsAnimation.fillMode = kCAFillModeForwards;
    boundsAnimation.removedOnCompletion = NO;
    boundsAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.318101 :-0.010734 :0.47469 :0.833742];
    boundsAnimation.keyPath = @"bounds";
    boundsAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, layerDimension, layerDimension)];
    
    [cellLayerLayer addAnimation:boundsAnimation forKey:@"boundsAnimation"];

    CABasicAnimation *boundsAnimation1 = [CABasicAnimation animation];
    boundsAnimation1.beginTime = [view.layer convertTime: CACurrentMediaTime() fromLayer: nil] + 0.5;
    boundsAnimation1.duration = 0.5;
    boundsAnimation1.fillMode = kCAFillModeForwards;
    boundsAnimation1.removedOnCompletion = NO;
    boundsAnimation1.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.318101 :-0.010734 :0.47469 :0.833742];
    boundsAnimation1.keyPath = @"bounds";
    boundsAnimation1.toValue = [NSValue valueWithCGRect:[[UIScreen mainScreen] bounds]];//CGRectMake(0, 0, 375, 667)];
    
    [cellLayerLayer addAnimation:boundsAnimation1 forKey:@"boundsAnimation1"];
    
    CABasicAnimation *positionAnimation = [CABasicAnimation animation];
    positionAnimation.beginTime = [view.layer convertTime: CACurrentMediaTime() fromLayer: nil] + 0.000001;
    positionAnimation.duration = 0.5;
    positionAnimation.fillMode = kCAFillModeForwards;
    positionAnimation.removedOnCompletion = NO;
    positionAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.318101 :-0.010734 :0.47469 :0.833742];
    positionAnimation.keyPath = @"position";
    
    CGPoint pos = CGPointMake(UIScreen.mainScreen.bounds.size.width / 2.f, UIScreen.mainScreen.bounds.size.height / 2.f);
    CGPoint realPos = [view.superview convertPoint:pos fromView:[[[UIApplication sharedApplication] windows] lastObject].rootViewController.view];
    positionAnimation.toValue = @(realPos);
    
    [cellLayerLayer addAnimation:positionAnimation forKey:@"positionAnimation"];

    CABasicAnimation *positionAnimation1 = [CABasicAnimation animation];
    positionAnimation1.beginTime = [view.layer convertTime: CACurrentMediaTime() fromLayer: nil] + 0.5;
    positionAnimation1.duration = 0.5;
    positionAnimation1.fillMode = kCAFillModeForwards;
    positionAnimation1.removedOnCompletion = NO;
    positionAnimation1.timingFunction = [CAMediaTimingFunction functionWithControlPoints:1.318101 :-0.010734 :0.47469 :0.833742];
    positionAnimation1.keyPath = @"position";
    positionAnimation1.toValue = positionAnimation.toValue;//[NSValue valueWithCGPoint:CGPointMake(0, 0)];
    
    [cellLayerLayer addAnimation:positionAnimation1 forKey:@"positionAnimation1"];

    CABasicAnimation *cornerRadiusAnimation = [CABasicAnimation animation];
    cornerRadiusAnimation.beginTime = [view.layer convertTime: CACurrentMediaTime() fromLayer: nil] + 0.000001;
    cornerRadiusAnimation.duration = 0.5;
    cornerRadiusAnimation.fillMode = kCAFillModeForwards;
    cornerRadiusAnimation.removedOnCompletion = NO;
    cornerRadiusAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.815163 :0.072007 :0.47469 :0.833742];
    cornerRadiusAnimation.keyPath = @"cornerRadius";
    cornerRadiusAnimation.toValue =  @(layerDimension / 2.f);//@(21);
    
    [cellLayerLayer addAnimation:cornerRadiusAnimation forKey:@"cornerRadiusAnimation"];
    
    CABasicAnimation *cornerRadiusAnimation1 = [CABasicAnimation animation];
    cornerRadiusAnimation1.beginTime = [view.layer convertTime: CACurrentMediaTime() fromLayer: nil] + 0.500001;
    cornerRadiusAnimation1.duration = 0.5;
    cornerRadiusAnimation1.fillMode = kCAFillModeForwards;
    cornerRadiusAnimation1.removedOnCompletion = NO;
    cornerRadiusAnimation1.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.815163 :0.072007 :0.47469 :0.833742];
    cornerRadiusAnimation1.keyPath = @"cornerRadius";
    cornerRadiusAnimation1.toValue = @(0);
    
    [cellLayerLayer addAnimation:cornerRadiusAnimation1 forKey:@"cornerRadiusAnimation1"];

    CABasicAnimation *backgroundColorAnimation = [CABasicAnimation animation];
    backgroundColorAnimation.beginTime = [view.layer convertTime: CACurrentMediaTime() fromLayer: nil] + 0.639024;
    backgroundColorAnimation.duration = 0.360976;
    backgroundColorAnimation.fillMode = kCAFillModeForwards;
    backgroundColorAnimation.removedOnCompletion = NO;
    backgroundColorAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    backgroundColorAnimation.keyPath = @"backgroundColor";
    backgroundColorAnimation.toValue = (__bridge id) color.CGColor;
    backgroundColorAnimation.delegate = delegate;

    [cellLayerLayer addAnimation:backgroundColorAnimation forKey:@"backgroundColorAnimation"];
}