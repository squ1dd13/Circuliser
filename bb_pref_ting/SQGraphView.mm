//
//  SQGraphView.m
//  grapjh
//
//  Created by Alex Gallon on 30/05/2020.
//  Copyright © 2020 Alex Gallon. All rights reserved.
//

#import "SQGraphView.hpp"



@implementation SQGraphDotView

-(void)saveCenter {
    savedCenter = self.center;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    ((UITableView *)(self.superview.superview.superview)).scrollEnabled = NO;
    isDragging = YES;
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = CGAffineTransformMakeScale(1.75, 1.75);
    } completion:nullptr];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    ((UITableView *)(self.superview.superview.superview)).scrollEnabled = NO;
    static UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen prepare];
    
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:self.superview];
    
    static bool wasPastEndBefore = false;
    
    if (isDragging) {
        [UIView animateWithDuration:0.05f
                              delay:0.0f
                            options:(UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut)
                         animations:^{
            
            float x = self->savedCenter.x;//std::min((float)self.superview.frame.size.width, std::max(0.f, (float)touchLocation.x));
            float y = std::min((float)self.superview.frame.size.height, std::max(0.f, (float)touchLocation.y));
            
            float intensity = std::abs(touchLocation.y - y);
            if(intensity > 0.f and not wasPastEndBefore) {
                [gen impactOccurred];
                wasPastEndBefore = true;
            } else if(intensity == 0.f) {
                wasPastEndBefore = false;
            }
            
            self.center = CGPointMake(x, y);
            ((SQGraphView *)self.superview)->draggablePointValues[self->index] = y / self.superview.frame.size.height;
            
        }
                         completion:NULL];
        
        [((SQGraphView *)self.superview) refresh];
    }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    ((UITableView *)(self.superview.superview.superview)).scrollEnabled = YES;
    float interpretedValue = self.center.y / self.superview.frame.size.height;
    if(std::abs(interpretedValue - 0.5f) <= 0.08f) {
        ((SQGraphView *)self.superview)->draggablePointValues[self->index] = 0.5f;
        self.center = CGPointMake(self.center.x, 0.5f * self.superview.frame.size.height);
        [((SQGraphView *)self.superview) refresh];
    }
    
    [UIView animateWithDuration:0.1
                          delay:0.0
                        options:0
                     animations:^{
        
        self.transform = CGAffineTransformMakeScale(1.0, 1.0);
    }
                     completion:^(BOOL finished) {
        
    }];
    //}
    
    
    
    
    isDragging = NO;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    ((UITableView *)(self.superview.superview.superview)).scrollEnabled = YES;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGFloat margin = 20.0;
    CGRect area = CGRectInset(self.bounds, -margin, -margin);
    return CGRectContainsPoint(area, point);
}
@end

@implementation SQGraphView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    ((UITableView *)(self.superview.superview)).scrollEnabled = NO;
}
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    ((UITableView *)(self.superview.superview)).scrollEnabled = NO;
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    ((UITableView *)(self.superview.superview)).scrollEnabled = YES;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [[self nextResponder] touchesEnded:touches withEvent:event];
    [super touchesEnded:touches withEvent:event];
    ((UITableView *)(self.superview.superview)).scrollEnabled = YES;
}

-(instancetype)initWithFrame:(CGRect)frame {
    savedFrame = frame;
    self = [super initWithFrame:frame];
    self.userInteractionEnabled = true;
    gradient = [CAGradientLayer new];

    auto frm = frame;
    frm.origin.x = 0;
    gradient.frame = frm;
   
    CAShapeLayer *centerLine = [CAShapeLayer new];
    centerLine.strokeColor = [[UIColor whiteColor] CGColor];
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, nullptr, 0, frame.size.height / 2.f);
    CGPathAddLineToPoint(path, nullptr, frame.size.width, frame.size.height / 2.f);
    
    CAGradientLayer *dashGradient = [CAGradientLayer new];
    dashGradient.colors = @[(__bridge id)([[UIColor clearColor] CGColor]), (__bridge id)([[UIColor whiteColor] CGColor]), (__bridge id)([[UIColor whiteColor] CGColor]), (__bridge id)([[UIColor clearColor] CGColor])];
    dashGradient.locations = @[@0, @0.1f, @0.9f, @1];
    dashGradient.frame = frm;
    dashGradient.startPoint = CGPointMake(0.0, 0.5);
    dashGradient.endPoint = CGPointMake(1.0, 0.5);
    dashGradient.opacity = 0.6f;
    
    centerLine.path = path;
    centerLine.lineDashPattern = @[@5, @5];
    
    dashGradient.mask = centerLine;
    [self.layer addSublayer:dashGradient];
    
    CGPathRelease(path);
    return self;
}

-(void)setUpPoints:(int)count withValues:(float *)values {
    
    gradient.colors = @[(__bridge id)(color.CGColor), (__bridge id)([UIColor clearColor].CGColor)];
    gradient.locations = @[@0, @1];
    
    [self.layer addSublayer:gradient];
    
    self.draggablePoints = count;
    draggablePointValues = {};
    
    //self.defaultValue = values[0];
    
    //std::vector<float> dpv {};

    for(int i = 0; i < self.draggablePoints; ++i) {
        draggablePointValues.push_back(values[i]);
    }
    
    CGMutablePathRef maskPath = CGPathCreateMutable();
    CGMutablePathRef graphPath = CGPathCreateMutable();
    
    float xInc = self.frame.size.width / float(count - 1);
    float yInc = self.frame.size.height;
    
    CGPathMoveToPoint(maskPath, nullptr, 0, self.frame.size.height);
    CGPathAddLineToPoint(maskPath, nullptr, 0, yInc * draggablePointValues[0]);
    
    for (int i = 0; i < count; i++) {
        CGPoint coordinate {xInc * float(i), yInc * draggablePointValues[i]};//= [self.coordinates[i] CGPointValue];
        
        SQGraphDotView *dot = [[SQGraphDotView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
        dot.center = coordinate; //CGPointMake(frame.size.width / 2.f, frame.size.height / 2.f);
        dot.backgroundColor = [UIColor whiteColor];
        dot.layer.cornerRadius = 10;
        dot->index = i;
        dot.layer.zPosition = 100;
        [dot saveCenter];
        
        [self addSubview:dot];
        
        if (!i) {
            CGPathMoveToPoint(graphPath, NULL, coordinate.x, coordinate.y);
        } else {
            CGPathAddLineToPoint(graphPath, NULL, coordinate.x, coordinate.y);
        }
    }
    
    CGPathAddPath(maskPath, nullptr, graphPath);
    CGPathAddLineToPoint(maskPath, nullptr, xInc * float(count - 1), self.frame.size.height);
    CGPathAddLineToPoint(maskPath, nullptr, 0, self.frame.size.height);
    
    graphLayer = [CAShapeLayer new];
    graphLayer.path = graphPath;
    graphLayer.strokeColor = color.CGColor;
    graphLayer.lineWidth = 2.f;
    graphLayer.fillColor = [UIColor clearColor].CGColor;
    graphLayer.fillMode = kCAFillModeForwards;
    
    [self.layer addSublayer:graphLayer];
    
    maskLayer = [CAShapeLayer new];
    maskLayer.path = maskPath;
    maskLayer.fillColor = [[UIColor whiteColor] CGColor];
    maskLayer.strokeColor = [[UIColor clearColor] CGColor];
    maskLayer.lineWidth = 0.f;
    
    gradient.mask = maskLayer;
    
    CGPathRelease(maskPath);
    CGPathRelease(graphPath);
}

-(void)refresh {
    CGMutablePathRef maskPath = CGPathCreateMutable();
    CGMutablePathRef graphPath = CGPathCreateMutable();

    float xInc = self.frame.size.width / float(draggablePointValues.size() - 1);
    float yInc = self.frame.size.height;

    CGPathMoveToPoint(maskPath, nullptr, 0, self.frame.size.height);
    CGPathAddLineToPoint(maskPath, nullptr, 0, yInc * draggablePointValues[0]);

    for (NSUInteger i = 0; i < draggablePointValues.size(); i++) {
        CGPoint coordinate {xInc * float(i), yInc * draggablePointValues[i]};//= [self.coordinates[i] CGPointValue];

        if (!i) {
            CGPathMoveToPoint(graphPath, NULL, coordinate.x, coordinate.y);
        } else {
            CGPathAddLineToPoint(graphPath, NULL, coordinate.x, coordinate.y);
        }
    }

    CGPathAddPath(maskPath, nullptr, graphPath);
    CGPathAddLineToPoint(maskPath, nullptr, xInc * float(draggablePointValues.size() - 1), self.frame.size.height);
    CGPathAddLineToPoint(maskPath, nullptr, 0, self.frame.size.height);

    graphLayer.path = graphPath;
    maskLayer.path = maskPath;
    gradient.mask = maskLayer;
    
    CGPathRelease(maskPath);
    CGPathRelease(graphPath);
}

- (BOOL) pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    
    if (self.clipsToBounds) {
        return nil;
    }
    
    if (self.hidden) {
        return nil;
    }
    
    if (self.alpha == 0) {
        return nil;
    }
    
    for (UIView *subview in self.subviews.reverseObjectEnumerator) {
        CGPoint subPoint = [subview convertPoint:point fromView:self];
        UIView *result = [subview hitTest:subPoint withEvent:event];
        
        if (result) {
            return result;
        }
    }
    
    return self;
}
 
@end
