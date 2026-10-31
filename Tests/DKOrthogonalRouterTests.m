/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKit/DiagramKit.h>

/* Orthogonal routes: right angles only, from edge to edge, round what is
 * in the way; and routes kept when their ends move. */
@interface DKOrthogonalRouterTests : XCTestCase
@end

@implementation DKOrthogonalRouterTests

static NSValue *
DKP(double x, double y)
{
	return [NSValue valueWithPoint:NSMakePoint(x, y)];
}

static BOOL
DKOnEdge(NSPoint p, NSRect r)
{
	BOOL withinX = p.x >= NSMinX(r) - 0.01 && p.x <= NSMaxX(r) + 0.01;
	BOOL withinY = p.y >= NSMinY(r) - 0.01 && p.y <= NSMaxY(r) + 0.01;
	BOOL onVertical = fabs(p.x - NSMinX(r)) < 0.01 || fabs(p.x - NSMaxX(r)) < 0.01;
	BOOL onHorizontal = fabs(p.y - NSMinY(r)) < 0.01 || fabs(p.y - NSMaxY(r)) < 0.01;
	return withinX && withinY && (onVertical || onHorizontal);
}

/* Right angles, from the source's edge to the target's, through neither. */
- (void)checkRoute:(NSArray<NSValue *> *)route from:(NSRect)source to:(NSRect)target
{
	XCTAssertGreaterThanOrEqual([route count], 2u);
	for (NSUInteger i = 1; i < [route count]; i++) {
		NSPoint a = [[route objectAtIndex:i - 1] pointValue], b = [[route objectAtIndex:i] pointValue];
		XCTAssertTrue(fabs(a.x - b.x) < 0.01 || fabs(a.y - b.y) < 0.01, @"segment %lu slants: %@",
		              (unsigned long)i, route);
		XCTAssertFalse(NSEqualPoints(a, b), @"a repeated point: %@", route);
	}
	XCTAssertTrue(DKOnEdge([[route firstObject] pointValue], source), @"%@ starts off %@", route, NSStringFromRect(source));
	XCTAssertTrue(DKOnEdge([[route lastObject] pointValue], target), @"%@ ends off %@", route, NSStringFromRect(target));
	for (NSUInteger i = 1; i + 1 < [route count]; i++) {
		NSPoint bend = [[route objectAtIndex:i] pointValue];
		XCTAssertFalse(NSPointInRect(bend, NSInsetRect(source, 1, 1)), @"a bend inside the source: %@", route);
		XCTAssertFalse(NSPointInRect(bend, NSInsetRect(target, 1, 1)), @"a bend inside the target: %@", route);
	}
}

- (void)testLevelShapesAreJoinedStraightAcross
{
	NSRect s = NSMakeRect(0, 0, 80, 40), t = NSMakeRect(200, 10, 80, 40);
	NSArray *route = [DKOrthogonalRouter routeFrom:s to:t avoiding:@[]];
	[self checkRoute:route from:s to:t];
	XCTAssertEqual([route count], 2u, @"straight: %@", route);
	XCTAssertEqual([[route firstObject] pointValue].x, 80.0);
	XCTAssertEqual([[route lastObject] pointValue].x, 200.0);
}

- (void)testShapesAtAnAngleGetRightAngles
{
	NSRect s = NSMakeRect(0, 0, 80, 40);
	NSArray *targets = @[ [NSValue valueWithRect:NSMakeRect(300, 200, 80, 40)],
		[NSValue valueWithRect:NSMakeRect(-300, 250, 60, 60)], [NSValue valueWithRect:NSMakeRect(20, 300, 80, 40)],
		[NSValue valueWithRect:NSMakeRect(-200, -300, 40, 40)], [NSValue valueWithRect:NSMakeRect(85, 45, 30, 30)] ];
	for (NSValue *value in targets) {
		NSRect t = [value rectValue];
		NSArray *route = [DKOrthogonalRouter routeFrom:s to:t avoiding:@[]];
		[self checkRoute:route from:s to:t];
		XCTAssertLessThanOrEqual([route count], 4u, @"no more bends than it needs: %@", route);
	}
}

- (void)testItGoesRoundAnObstacleWhenItCan
{
	NSRect s = NSMakeRect(0, 0, 60, 40), t = NSMakeRect(300, 0, 60, 40);
	NSArray *obstacles = @[ [NSValue valueWithRect:NSMakeRect(150, -10, 40, 60)] ];
	NSArray *straight = @[ DKP(60, 20), DKP(300, 20) ];
	XCTAssertEqual([DKOrthogonalRouter crossingsOfRoute:straight obstacles:obstacles], 1u);
	NSArray *route = [DKOrthogonalRouter routeFrom:s to:t avoiding:obstacles];
	[self checkRoute:route from:s to:t];
	XCTAssertEqual([DKOrthogonalRouter crossingsOfRoute:route obstacles:obstacles], 0u, @"%@", route);
	/* Walled in on every side but one: out that way. */
	NSArray *walls = @[ [NSValue valueWithRect:NSMakeRect(-40, -80, 140, 30)],
		[NSValue valueWithRect:NSMakeRect(-40, 90, 140, 30)], [NSValue valueWithRect:NSMakeRect(-80, -80, 30, 200)],
		[NSValue valueWithRect:NSMakeRect(150, -10, 40, 60)] ];
	route = [DKOrthogonalRouter routeFrom:s to:t avoiding:walls];
	[self checkRoute:route from:s to:t];
	XCTAssertEqual([DKOrthogonalRouter crossingsOfRoute:route obstacles:walls], 0u, @"%@", route);
}

- (void)testWhenItCannotAvoidItCrossesTheFewest
{
	NSRect s = NSMakeRect(0, 0, 60, 40), t = NSMakeRect(300, 0, 60, 40);
	/* A wall round the target: one must be crossed, never more. */
	NSArray *box = @[ [NSValue valueWithRect:NSMakeRect(260, -1000, 10, 2040)],
		[NSValue valueWithRect:NSMakeRect(390, -1000, 10, 2040)], [NSValue valueWithRect:NSMakeRect(260, -1000, 140, 10)],
		[NSValue valueWithRect:NSMakeRect(260, 1030, 140, 10)] ];
	NSArray *route = [DKOrthogonalRouter routeFrom:s to:t avoiding:box];
	[self checkRoute:route from:s to:t];
	XCTAssertEqual([DKOrthogonalRouter crossingsOfRoute:route obstacles:box], 1u, @"%@", route);
}

- (void)testTheSidesGiven
{
	NSRect s = NSMakeRect(0, 0, 60, 40), t = NSMakeRect(200, 200, 60, 40);
	/* Down out of the source (a boundary event's flow), into the target's left. */
	NSArray *route = [DKOrthogonalRouter routeFrom:s sides:DKRouteSideBottom to:t sides:DKRouteSideLeft avoiding:@[]];
	[self checkRoute:route from:s to:t];
	NSPoint first = [[route firstObject] pointValue], last = [[route lastObject] pointValue];
	XCTAssertEqual(first.y, NSMaxY(s));
	XCTAssertEqual(last.x, NSMinX(t));
	XCTAssertEqual([route count], 3u, @"down, then across: %@", route);
	/* The top and bottom only, for a target level with it: round. */
	NSRect level = NSMakeRect(200, 0, 60, 40);
	route = [DKOrthogonalRouter routeFrom:s sides:DKRouteSidesVertical to:level sides:DKRouteSidesVertical avoiding:@[]];
	[self checkRoute:route from:s to:level];
	first = [[route firstObject] pointValue];
	XCTAssertTrue(first.y == NSMinY(s) || first.y == NSMaxY(s), @"%@", route);
}

- (void)testItIsDeterministic
{
	NSRect s = NSMakeRect(0, 0, 60, 40), t = NSMakeRect(250, 120, 60, 40);
	NSArray *obstacles = @[ [NSValue valueWithRect:NSMakeRect(120, 0, 40, 200)] ];
	XCTAssertEqualObjects([DKOrthogonalRouter routeFrom:s to:t avoiding:obstacles],
	                      [DKOrthogonalRouter routeFrom:s to:t avoiding:obstacles]);
}

#pragma mark Kept

- (void)testAMovedEndKeepsTheBends
{
	/* Across, down, across: the target moves down by 30. */
	NSArray *route = @[ DKP(80, 20), DKP(140, 20), DKP(140, 120), DKP(200, 120) ];
	NSRect source = NSMakeRect(0, 0, 80, 40), target = NSMakeRect(200, 130, 80, 40);
	NSArray *kept = [DKOrthogonalRouter keptRoute:route source:source target:target sourceMoved:NSZeroSize
	                                  targetMoved:NSMakeSize(0, 30)];
	XCTAssertNotNil(kept);
	NSArray *expected = @[ DKP(80, 20), DKP(140, 20), DKP(140, 150), DKP(200, 150) ];
	XCTAssertEqualObjects(kept, expected);
	/* The source moved right: the first bend slides with its level segment. */
	kept = [DKOrthogonalRouter keptRoute:route source:NSOffsetRect(source, 10, 5) target:NSOffsetRect(target, 0, -30)
	                         sourceMoved:NSMakeSize(10, 5)
	                         targetMoved:NSZeroSize];
	XCTAssertEqualObjects(kept, (@[ DKP(90, 25), DKP(140, 25), DKP(140, 120), DKP(200, 120) ]));
}

- (void)testARouteThatCannotBeKeptIsNil
{
	NSArray *route = @[ DKP(80, 20), DKP(140, 20), DKP(140, 120), DKP(200, 120) ];
	/* The source moved past the bend: the bend would be inside it. */
	NSRect source = NSMakeRect(100, 0, 80, 40);
	XCTAssertNil([DKOrthogonalRouter keptRoute:route source:source target:NSMakeRect(200, 100, 80, 40)
	                               sourceMoved:NSMakeSize(100, 0)
	                               targetMoved:NSZeroSize]);
	/* A straight route has no bends to keep. */
	NSArray *straight = @[ DKP(80, 20), DKP(200, 20) ];
	XCTAssertNil([DKOrthogonalRouter keptRoute:straight source:NSMakeRect(0, 0, 80, 40)
	                                    target:NSMakeRect(200, 0, 80, 40)
	                               sourceMoved:NSMakeSize(0, 10)
	                               targetMoved:NSZeroSize]);
	/* The target moved back over its bend. */
	XCTAssertNil([DKOrthogonalRouter keptRoute:route source:NSMakeRect(0, 0, 80, 40) target:NSMakeRect(100, 100, 80, 40)
	                               sourceMoved:NSZeroSize
	                               targetMoved:NSMakeSize(-100, 0)]);
}

@end
