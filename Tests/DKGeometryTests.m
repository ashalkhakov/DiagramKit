/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKit/DiagramKit.h>

/* The geometry: edge points, distances, a route's middle, free spots;
 * and paths. */
@interface DKGeometryTests : XCTestCase
@end

@implementation DKGeometryTests

- (void)testTheEdgePointIsOnTheEdgeTowardThePoint
{
	NSRect rect = NSMakeRect(0, 0, 100, 50);
	NSPoint right = DKEdgePoint(rect, NSMakePoint(300, 25));
	XCTAssertEqualWithAccuracy(right.x, 100, 0.001);
	XCTAssertEqualWithAccuracy(right.y, 25, 0.001);
	NSPoint below = DKEdgePoint(rect, NSMakePoint(50, 400));
	XCTAssertEqualWithAccuracy(below.y, 50, 0.001);
	NSPoint corner = DKEdgePoint(rect, NSMakePoint(150, 75));
	XCTAssertEqualWithAccuracy(corner.x, 100, 0.001);
	XCTAssertEqualWithAccuracy(corner.y, 50, 0.001);
	NSPoint centre = DKEdgePoint(rect, NSMakePoint(50, 25));
	XCTAssertTrue(NSEqualPoints(centre, NSMakePoint(50, 25)));
}

- (void)testDistances
{
	XCTAssertEqualWithAccuracy(DKDistanceToSegment(NSMakePoint(5, 3), NSMakePoint(0, 0), NSMakePoint(10, 0)), 3, 1e-9);
	XCTAssertEqualWithAccuracy(DKDistanceToSegment(NSMakePoint(13, 4), NSMakePoint(0, 0), NSMakePoint(10, 0)), 5, 1e-9);
	XCTAssertEqualWithAccuracy(DKDistanceToSegment(NSMakePoint(3, 4), NSMakePoint(0, 0), NSMakePoint(0, 0)), 5, 1e-9);
	NSArray *route = @[ [NSValue valueWithPoint:NSMakePoint(0, 0)], [NSValue valueWithPoint:NSMakePoint(10, 0)],
		[NSValue valueWithPoint:NSMakePoint(10, 10)] ];
	XCTAssertEqualWithAccuracy(DKDistanceToRoute(NSMakePoint(12, 5), route), 2, 1e-9);
	XCTAssertEqualWithAccuracy(DKDistanceToRoute(NSMakePoint(5, -1), route), 1, 1e-9);
	XCTAssertTrue(isinf(DKDistanceToRoute(NSMakePoint(0, 0), @[])));
	XCTAssertEqualWithAccuracy(DKRouteLength(route), 20, 1e-9);
	NSPoint middle = DKRouteMidpoint(route);
	XCTAssertEqualWithAccuracy(middle.x, 10, 1e-9);
	XCTAssertEqualWithAccuracy(middle.y, 0, 1e-9);
	XCTAssertTrue(NSEqualRects(DKRouteBounds(route), NSMakeRect(0, 0, 10, 10)));
}

- (void)testAFreeSpotNearIsClearOfWhatIsThere
{
	NSArray *occupied = @[ [NSValue valueWithRect:NSMakeRect(100, 100, 80, 50)],
		[NSValue valueWithRect:NSMakeRect(190, 100, 80, 50)] ];
	NSRect clear = DKFreeSpotNear(NSMakeSize(60, 40), NSMakePoint(400, 400), occupied, 4);
	XCTAssertTrue(NSEqualRects(clear, NSMakeRect(370, 380, 60, 40)), @"centred where it is free: %@",
	              NSStringFromRect(clear));
	NSRect spot = DKFreeSpotNear(NSMakeSize(60, 40), NSMakePoint(140, 125), occupied, 4);
	for (NSValue *value in occupied) {
		XCTAssertFalse(NSIntersectsRect(NSInsetRect(spot, -4, -4), [value rectValue]), @"%@", NSStringFromRect(spot));
	}
	XCTAssertLessThan(hypot(NSMidX(spot) - 140, NSMidY(spot) - 125), 150.0, @"and near");
	XCTAssertGreaterThanOrEqual(NSMinX(spot), 0.0);
	XCTAssertGreaterThanOrEqual(NSMinY(spot), 0.0);
	/* Never above or left of the origin. */
	NSRect corner = DKFreeSpotNear(NSMakeSize(60, 40), NSMakePoint(0, 0), @[], 4);
	XCTAssertGreaterThanOrEqual(NSMinX(corner), 0.0);
	XCTAssertGreaterThanOrEqual(NSMinY(corner), 0.0);
}

- (void)testPathsAndTheirShapes
{
	DKPath *rect = [DKPath pathWithRect:NSMakeRect(1, 2, 30, 40)];
	XCTAssertEqual(rect.shape, DKPathShapeRect);
	XCTAssertTrue(NSEqualRects(rect.bounds, NSMakeRect(1, 2, 30, 40)));
	DKPath *rounded = [DKPath pathWithRoundedRect:NSMakeRect(0, 0, 40, 10) radius:8];
	XCTAssertEqual(rounded.shape, DKPathShapeRoundedRect);
	XCTAssertEqual(rounded.radius, 5.0, @"at most half the shorter side");
	XCTAssertTrue(NSEqualRects(rounded.bounds, NSMakeRect(0, 0, 40, 10)));
	DKPath *oval = [DKPath pathWithOvalInRect:NSMakeRect(10, 10, 20, 10)];
	XCTAssertEqual(oval.shape, DKPathShapeOval);
	XCTAssertTrue(NSEqualRects(oval.bounds, NSMakeRect(10, 10, 20, 10)));
	NSPoint p[3];
	XCTAssertEqual([oval elementAtIndex:1 points:p], DKPathCurveTo);
	DKPath *line = [DKPath pathWithPoints:@[ [NSValue valueWithPoint:NSMakePoint(0, 0)],
	                                         [NSValue valueWithPoint:NSMakePoint(5, 9)] ]];
	XCTAssertEqual(line.elementCount, 2u);
	XCTAssertEqual(line.shape, DKPathShapeNone);
	DKPath *changed = [rect copy];
	[changed lineTo:NSMakePoint(100, 100)];
	XCTAssertEqual(changed.shape, DKPathShapeNone, @"added to: a plain path");
	XCTAssertEqual(rect.shape, DKPathShapeRect);
	XCTAssertTrue([[DKPath path] isEmpty]);
	XCTAssertTrue(NSEqualRects([DKPath path].bounds, NSZeroRect));
	DKPath *curve = [DKPath path];
	[curve moveTo:NSMakePoint(0, 0)];
	[curve curveTo:NSMakePoint(10, 0) control1:NSMakePoint(0, 10) control2:NSMakePoint(10, 10)];
	XCTAssertTrue(NSEqualRects(curve.bounds, NSMakeRect(0, 0, 10, 10)));
}

- (void)testColoursAndFonts
{
	XCTAssertEqualObjects(DKColorHex(DKColorMake(0.5, 0, 0.5, 1)), @"#800080");
	XCTAssertEqualObjects(DKColorHex(DKColorMake(2, -1, 1, 1)), @"#ff00ff");
	XCTAssertTrue(DKColorEqual(DKColorWithAlpha(DKColorBlack(), 0.5), DKColorMake(0, 0, 0, 0.5)));
	DKFont *font = [DKFont systemFontOfSize:11 bold:YES];
	XCTAssertNil(font.name);
	XCTAssertEqual(font.size, 11.0);
	XCTAssertTrue(font.bold);
	XCTAssertEqualObjects(font, [DKFont fontWithName:nil size:11 bold:YES]);
	XCTAssertNil([DKFont fontWithName:@"" size:11 bold:NO].name, @"an empty name is the system font's");
	XCTAssertEqualObjects([DKFont fontWithName:@"Menlo" size:9 bold:NO].name, @"Menlo");
}

@end
