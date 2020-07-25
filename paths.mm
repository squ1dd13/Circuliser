#define VALUE(_INDEX_) [NSValue valueWithCGPoint:points[_INDEX_]]

@implementation UIBezierPath (Points)
void pointsFromBezier(void *info, const CGPathElement *element) {
    NSMutableArray *bezierPoints = (__bridge NSMutableArray *)info;

    // Retrieve the path element type and its points
    CGPathElementType type = element->type;
    CGPoint *points = element->points;

    // Add the points if they're available (per type)
    if(type != kCGPathElementCloseSubpath) {
        [bezierPoints addObject:VALUE(0)];
        if((type != kCGPathElementAddLineToPoint) &&
           (type != kCGPathElementMoveToPoint))
            [bezierPoints addObject:VALUE(1)];
    }

    if(type == kCGPathElementAddCurveToPoint)
        [bezierPoints addObject:VALUE(2)];
}

void isSubPathClosed(void *info, const CGPathElement *element) {
    BOOL *subPathIsClosed = (BOOL *)info;
    if(*subPathIsClosed)
        return;

    // Retrieve the path element type and its points
    CGPathElementType type = element->type;

    // Add the points if they're available (per type)
    if(type == kCGPathElementCloseSubpath) {
        *subPathIsClosed = YES;
        return;
    }
}

- (NSArray *)points {
    NSMutableArray *points = [NSMutableArray array];
    CGPathApply(self.CGPath, (__bridge void *)points, pointsFromBezier);
    return points;
}

- (BOOL)pathIsClosed {
    BOOL pathIsClosed = NO;
    CGPathApply(self.CGPath, (void *)&pathIsClosed, isSubPathClosed);
    return pathIsClosed;
}
@end

#define POINT(_INDEX_) [(NSValue *)[points objectAtIndex:_INDEX_] CGPointValue]

@implementation UIBezierPath (Smoothin)
- (UIBezierPath *)smoothedPath:(int)granularity {
    NSMutableArray *points = [self.points mutableCopy];
    if(points.count < 4)
        return [self copy];

    // Add control points to make the math make sense
    // Via Josh Weinberg
    [points insertObject:[points objectAtIndex:0] atIndex:0];
    [points addObject:[points lastObject]];

    UIBezierPath *smoothedPath = [UIBezierPath bezierPath];

    // Copy traits
    smoothedPath.lineWidth = self.lineWidth;

    // Draw out the first 3 points (0..2)
    [smoothedPath moveToPoint:POINT(0)];

    for(int index = 1; index < 3; index++)
        [smoothedPath addLineToPoint:POINT(index)];

    for(int index = 4; index < points.count; index++) {
        CGPoint p0 = POINT(index - 3);
        CGPoint p1 = POINT(index - 2);
        CGPoint p2 = POINT(index - 1);
        CGPoint p3 = POINT(index);

        // now add n points starting at p1 + dx/dy up
        // until p2 using Catmull-Rom splines
        for(int i = 1; i < granularity; i++)

        {
            float t = (float)i * (1.0f / (float)granularity);
            float tt = t * t;
            float ttt = tt * t;

            CGPoint pi; // intermediate point
            pi.x = 0.5 * (2 * p1.x + (p2.x - p0.x) * t +
                          (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * tt + (3 * p1.x - p0.x - 3 * p2.x + p3.x) * ttt);
            pi.y = 0.5 * (2 * p1.y + (p2.y - p0.y) * t +
                          (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * tt + (3 * p1.y - p0.y - 3 * p2.y + p3.y) * ttt);
            [smoothedPath addLineToPoint:pi];
        }

        // Now add p2
        [smoothedPath addLineToPoint:p2];
    }

    // finish by adding the last point
    [smoothedPath addLineToPoint:POINT(points.count - 1)];

    return smoothedPath;
}

- (UIBezierPath *)properSmoothedPath:(int)granularity {
    NSMutableArray *points = [self.points mutableCopy];

    BOOL pathIsClosed = [self pathIsClosed];
    //  NSString *notString = pathIsClosed ? @"" : @" not";
    //  NSLog(@"Path is%@ closed", notString);

    if(points.count < 4)
        return [self copy];

    // Add control points to make the math make sense
    // Via Josh Weinberg
    if(!pathIsClosed) {
        [points insertObject:[points objectAtIndex:0] atIndex:0];
        [points addObject:[points lastObject]];
    }

    UIBezierPath *smoothedPath = [UIBezierPath bezierPath];

    // Copy traits
    smoothedPath.lineWidth = self.lineWidth;

    // Draw out the first 3 points (0..2)
    [smoothedPath moveToPoint:POINT(0)];

    if(!pathIsClosed)
        [smoothedPath addLineToPoint:POINT(1)];

    int start = 3;
    NSUInteger end = points.count;
    if(pathIsClosed) {
        start--;
        end += 2;
    }
    for(int index = start; index < end; index++) {
        CGPoint p0 = POINT((points.count + index - 3) % points.count);
        CGPoint p1 = POINT((points.count + index - 2) % points.count);
        CGPoint p2 = POINT((points.count + index - 1) % points.count);
        CGPoint p3 = POINT(index % points.count);

        // now add n points starting at p1 + dx/dy up until p2 using Catmull-Rom splines
        for(int i = 1; i < granularity; i++) {
            float t = (float)i * (1.0f / (float)granularity);
            float tt = t * t;
            float ttt = tt * t;

            CGPoint pi; // intermediate point
            pi.x = 0.5 * (2 * p1.x + (p2.x - p0.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * tt + (3 * p1.x - p0.x - 3 * p2.x + p3.x) * ttt);
            pi.y = 0.5 * (2 * p1.y + (p2.y - p0.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * tt + (3 * p1.y - p0.y - 3 * p2.y + p3.y) * ttt);
            [smoothedPath addLineToPoint:pi];
        }

        // Now add p2
        [smoothedPath addLineToPoint:p2];
    }

    // finish by adding the last point
    if(!pathIsClosed)
        [smoothedPath addLineToPoint:POINT(points.count - 1)];
    if(pathIsClosed)
        [smoothedPath closePath];
    return smoothedPath;
}

@end

@interface UIBezierPath (Interpolation)
@end

static CGPoint midPointForPoints(CGPoint p1, CGPoint p2) {
    return CGPointMake((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
}

static CGPoint controlPointForPoints(CGPoint p1, CGPoint p2) {
    CGPoint controlPoint = midPointForPoints(p1, p2);
    CGFloat diffY = abs(p2.y - controlPoint.y);

    if(p1.y < p2.y)
        controlPoint.y += diffY;
    else if(p1.y > p2.y)
        controlPoint.y -= diffY;

    return controlPoint;
}

@implementation UIBezierPath (Interpolation)

- (void)addQuadCurveToPointSub:(CGPoint)endPoint controlPoint:(CGPoint)controlPoint {
    auto startPoint = self.currentPoint;
    auto controlPoint1 = CGPointMake((startPoint.x + (controlPoint.x - startPoint.x) * 2.0 / 3.0), (startPoint.y + (controlPoint.y - startPoint.y) * 2.0 / 3.0));
    auto controlPoint2 = CGPointMake((endPoint.x + (controlPoint.x - endPoint.x) * 2.0 / 3.0), (endPoint.y + (controlPoint.y - endPoint.y) * 2.0 / 3.0));

    [self addCurveToPoint:endPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
}

+ (UIBezierPath *)quadCurvedPathWithPoints:(NSArray *)points {
    UIBezierPath *path = [UIBezierPath bezierPath];

    NSValue *value = points[0];
    CGPoint p1 = [value CGPointValue];
    [path moveToPoint:p1];

    if(points.count == 2) {
        value = points[1];
        CGPoint p2 = [value CGPointValue];
        [path addLineToPoint:p2];
        return path;
    }

    for(NSUInteger i = 1; i < points.count; i++) {
        value = points[i];
        CGPoint p2 = [value CGPointValue];

        CGPoint midPoint = midPointForPoints(p1, p2);

        [path addQuadCurveToPointSub:midPoint controlPoint:controlPointForPoints(midPoint, p1)];
        [path addQuadCurveToPointSub:p2 controlPoint:controlPointForPoints(midPoint, p2)];

        p1 = p2;
    }

    return path;
}

@end

void getPointsFromBezier(void *info, const CGPathElement *element);
NSMutableArray *pointsFromBezierPath(UIBezierPath *bpath);

#define VALUE(_INDEX_) [NSValue valueWithCGPoint:points[_INDEX_]]
#define POINT(_INDEX_) [(NSValue *)[points objectAtIndex:_INDEX_] CGPointValue]

@implementation UIBezierPath (Smoothing)

void pointFromPathHandler(void *info, const CGPathElement *element) {
    std::vector<CGPoint> *bezierPoints = (std::vector<CGPoint> *)info;

    CGPathElementType type = element->type;
    CGPoint *points = element->points;

    if(type != kCGPathElementCloseSubpath) {
        bezierPoints->push_back(points[0]);
        if((type != kCGPathElementAddLineToPoint) and (type != kCGPathElementMoveToPoint))
            bezierPoints->push_back(points[1]);
    }

    if(type == kCGPathElementAddCurveToPoint)
        bezierPoints->push_back(points[2]);
}

// Get points from Bezier Curve
void getPointsFromBezier(void *info, const CGPathElement *element) {
    NSMutableArray *bezierPoints = (__bridge NSMutableArray *)info;

    // Retrieve the path element type and its points
    CGPathElementType type = element->type;
    CGPoint *points = element->points;

    // Add the points if they're available (per type)
    if(type != kCGPathElementCloseSubpath) {
        [bezierPoints addObject:VALUE(0)];
        if((type != kCGPathElementAddLineToPoint) &&
           (type != kCGPathElementMoveToPoint))
            [bezierPoints addObject:VALUE(1)];
    }
    if(type == kCGPathElementAddCurveToPoint)
        [bezierPoints addObject:VALUE(2)];
}

void extractPointsFromPath(UIBezierPath *path, std::vector<CGPoint> &out) {
    try {
        CGPathApply([path CGPath], (void *)(&out), pointFromPathHandler);
    } catch(...) {
        os_log(OS_LOG_DEFAULT, "[BB] exc");
    }
}

NSMutableArray *pointsFromBezierPath(UIBezierPath *bpath) {
    NSMutableArray *points = [NSMutableArray array];
    CGPathApply([bpath CGPath], (__bridge void *)points, getPointsFromBezier);
    return points;
}

- (UIBezierPath *)smoothedPathWithGranularity:(NSInteger)granularity {

    NSMutableArray *points = [pointsFromBezierPath(self) mutableCopy];

    if(points.count < 4)
        return [self copy];

    // Add control points to make the math make sense
    [points insertObject:[points objectAtIndex:0] atIndex:0];
    [points addObject:[points lastObject]];

    UIBezierPath *smoothedPath = [self copy];
    [smoothedPath removeAllPoints];

    [smoothedPath moveToPoint:POINT(0)];

    for(NSUInteger index = 1; index < points.count - 2; index++) {
        CGPoint p0 = POINT(index - 1);
        CGPoint p1 = POINT(index);
        CGPoint p2 = POINT(index + 1);
        CGPoint p3 = POINT(index + 2);

        // now add n points starting at p1 + dx/dy up until p2 using Catmull-Rom splines
        for(int i = 1; i < granularity; i++) {
            float t = (float)i * (1.0f / (float)granularity);
            float tt = t * t;
            float ttt = tt * t;

            CGPoint pi; // intermediate point
            pi.x = 0.5 * (2 * p1.x + (p2.x - p0.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * tt + (3 * p1.x - p0.x - 3 * p2.x + p3.x) * ttt);
            pi.y = 0.5 * (2 * p1.y + (p2.y - p0.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * tt + (3 * p1.y - p0.y - 3 * p2.y + p3.y) * ttt);
            [smoothedPath addLineToPoint:pi];
        }

        // Now add p2
        [smoothedPath addLineToPoint:p2];
    }

    // finish by adding the last point
    [smoothedPath addLineToPoint:POINT(points.count - 1)];

    return smoothedPath;
}

- (void)smoothWithGranularity:(int)granularity {
    //NSMutableArray *points = pointsFromBezierPath(self);
    std::vector<CGPoint> points;
    extractPointsFromPath([self copy], points);

    if(points.size() < 4)
        return;

    // Add control points to make the math make sense
    //[points insertObject:[points objectAtIndex:0] atIndex:0];
    points.insert(points.begin(), points.front());
    //[points addObject:[points lastObject]];
    points.push_back(points.back());

    [self removeAllPoints];

    [self moveToPoint:points[0]];

    for(size_t index = 1; index < points.size() - 2; index++) {
        CGPoint p0 = points[index - 1]; //POINT(index - 1);
        CGPoint p1 = points[index];     //POINT(index);
        CGPoint p2 = points[index + 1];
        CGPoint p3 = points[index + 2];

        // now add n points starting at p1 + dx/dy up until p2 using Catmull-Rom splines
        for(int i = 1; i < granularity; i++) {
            float t = (float)i * (1.0f / (float)granularity);
            float tt = t * t;
            float ttt = tt * t;

            CGPoint pi; // intermediate point
            pi.x = 0.5 * (2 * p1.x + (p2.x - p0.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * tt + (3 * p1.x - p0.x - 3 * p2.x + p3.x) * ttt);
            pi.y = 0.5 * (2 * p1.y + (p2.y - p0.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * tt + (3 * p1.y - p0.y - 3 * p2.y + p3.y) * ttt);
            [self addLineToPoint:pi];
        }

        // Now add p2
        [self addLineToPoint:p2];
    }

    // finish by adding the last point
    [self addLineToPoint:points.back()];
}

@end