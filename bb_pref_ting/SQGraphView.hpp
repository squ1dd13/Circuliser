//
//  SQGraphView.h
//  grapjh
//
//  Created by Alex Gallon on 30/05/2020.
//  Copyright © 2020 Alex Gallon. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <vector>
#include <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface SQGraphDotView : UIView {
    bool isDragging;
    CGPoint savedCenter;
    @public int index;
}
@end    

@interface SQGraphView : UIView {
    CAGradientLayer *gradient;
    CAShapeLayer *graphLayer;
    CAShapeLayer *maskLayer;
    @public std::vector<float> draggablePointValues;
    @public UIColor *color;
    CGRect savedFrame;
}

@property int draggablePoints;
@property float defaultValue;

-(void)setUpPoints:(int)count withValues:(float *)values;
-(void)refresh;
@end

NS_ASSUME_NONNULL_END
