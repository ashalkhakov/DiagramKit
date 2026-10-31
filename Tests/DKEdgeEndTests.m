/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKit/DiagramKit.h>
#import "DKRecordingSurface.h"

/* Each end of an edge, drawn onto a recording surface: what it draws and
 * where, pointing the way the route goes. */
@interface DKEdgeEndTests : XCTestCase
@end

@implementation DKEdgeEndTests

static NSValue *
DKP(double x, double y)
{
	return [NSValue valueWithPoint:NSMakePoint(x, y)];
}

/* A route left to right, into (100, 50), its end the one given. */
static DKRecordingSurface *
DKDrawn(DKEdgeEnd end)
{
	DKRecordingSurface *surface = [[DKRecordingSurface alloc] init];
	DKDrawRoute(surface, @[ DKP(0, 50), DKP(100, 50) ], DKColorBlack(), 1, DKStrokeSolid, DKEdgeEndNone, end);
	return surface;
}

/* The route's line: the first stroke. */
static DKRecordedOperation *
DKLine(DKRecordingSurface *surface)
{
	return [[surface operationsOfKind:DKRecordedStroke] firstObject];
}

/* The marks: every operation after the line. */
static NSArray<DKRecordedOperation *> *
DKMarks(DKRecordingSurface *surface)
{
	NSMutableArray *marks = [surface.operations mutableCopy];
	[marks removeObjectAtIndex:0];
	return marks;
}

/* A bar across the line at @a x: a vertical stroke 12 points long. */
static BOOL
DKIsBarAt(DKRecordedOperation *operation, double x)
{
	NSRect r = operation.rect;
	return operation.kind == DKRecordedStroke && fabs(NSMinX(r) - x) < 0.01 && NSWidth(r) < 0.01
		&& fabs(NSHeight(r) - 12) < 0.01 && fabs(NSMidY(r) - 50) < 0.01;
}

- (void)testNoEndIsTheLineAlone
{
	DKRecordingSurface *surface = DKDrawn(DKEdgeEndNone);
	XCTAssertEqual([surface.operations count], 1u);
	XCTAssertTrue(NSEqualRects(DKLine(surface).rect, NSMakeRect(0, 50, 100, 0)));
	XCTAssertEqual(DKLine(surface).strokeStyle, DKStrokeSolid);
}

- (void)testArrows
{
	DKRecordingSurface *filled = DKDrawn(DKEdgeEndArrow);
	NSArray *marks = DKMarks(filled);
	XCTAssertEqual([marks count], 1u);
	DKRecordedOperation *head = [marks firstObject];
	XCTAssertEqual(head.kind, DKRecordedFill);
	XCTAssertEqualWithAccuracy(NSMaxX(head.rect), 100, 0.01, @"the tip on the end");
	XCTAssertEqualWithAccuracy(NSMidY(head.rect), 50, 0.01);
	XCTAssertLessThan(NSMinX(head.rect), 95.0);
	XCTAssertLessThanOrEqual(NSMaxX(DKLine(filled).rect), NSMaxX(head.rect), @"the line stops under the head");

	DKRecordingSurface *open = DKDrawn(DKEdgeEndOpenArrow);
	head = [DKMarks(open) firstObject];
	XCTAssertEqual(head.kind, DKRecordedStroke);
	XCTAssertEqual(DKPathPoints(head.path).count, 3u, @"a V");
	XCTAssertEqualWithAccuracy(NSMaxX(DKLine(open).rect), 100, 0.01, @"the line to the tip");
}

- (void)testTheTriangleAndDiamondsStopTheLine
{
	DKRecordingSurface *triangle = DKDrawn(DKEdgeEndTriangle);
	DKRecordedOperation *mark = [DKMarks(triangle) firstObject];
	XCTAssertEqual(mark.kind, DKRecordedStroke, @"hollow");
	XCTAssertEqualWithAccuracy(NSMaxX(mark.rect), 100, 0.01);
	XCTAssertEqualWithAccuracy(NSMaxX(DKLine(triangle).rect), NSMinX(mark.rect), 0.01, @"the line to its base");

	DKRecordingSurface *diamond = DKDrawn(DKEdgeEndDiamond);
	NSArray *marks = DKMarks(diamond);
	XCTAssertEqual([marks count], 1u);
	mark = [marks firstObject];
	XCTAssertEqualWithAccuracy(NSWidth(mark.rect), 14, 0.01);
	XCTAssertEqualWithAccuracy(NSHeight(mark.rect), 10, 0.01);
	XCTAssertEqualWithAccuracy(NSMaxX(DKLine(diamond).rect), 86, 0.01);

	DKRecordingSurface *filled = DKDrawn(DKEdgeEndFilledDiamond);
	marks = DKMarks(filled);
	XCTAssertEqual([marks count], 2u);
	XCTAssertEqual([(DKRecordedOperation *)[marks firstObject] kind], DKRecordedFill);
	XCTAssertTrue(NSEqualRects([[marks firstObject] rect], [[marks lastObject] rect]));
}

- (void)testOneIsTwoBars
{
	DKRecordingSurface *surface = DKDrawn(DKEdgeEndCrowFootOne);
	NSArray *marks = DKMarks(surface);
	XCTAssertEqual([marks count], 2u);
	XCTAssertTrue(DKIsBarAt([marks objectAtIndex:0], 92), @"%@", NSStringFromRect([[marks objectAtIndex:0] rect]));
	XCTAssertTrue(DKIsBarAt([marks objectAtIndex:1], 88), @"%@", NSStringFromRect([[marks objectAtIndex:1] rect]));
	XCTAssertEqualWithAccuracy(NSMaxX(DKLine(surface).rect), 100, 0.01, @"the line to the shape");
}

- (void)testZeroOrOneIsABarAndACircleTheLineDoesNotCross
{
	DKRecordingSurface *surface = DKDrawn(DKEdgeEndCrowFootZeroOrOne);
	NSArray *marks = DKMarks(surface);
	XCTAssertEqual([marks count], 2u);
	XCTAssertTrue(DKIsBarAt([marks objectAtIndex:0], 92));
	DKRecordedOperation *circle = [marks objectAtIndex:1];
	XCTAssertEqual(circle.path.shape, DKPathShapeOval);
	XCTAssertEqualWithAccuracy(NSMidX(circle.rect), 100 - 14.5, 0.01);
	XCTAssertEqualWithAccuracy(NSWidth(circle.rect), 7, 0.01);
	DKPath *line = DKLine(surface).path;
	XCTAssertEqual(DKPathMoves(line), 2u, @"the line in two, round the circle");
	NSArray *points = DKPathPoints(line);
	XCTAssertEqualWithAccuracy([[points objectAtIndex:1] pointValue].x, NSMinX(circle.rect), 0.01);
	XCTAssertEqualWithAccuracy([[points objectAtIndex:2] pointValue].x, NSMaxX(circle.rect), 0.01);
	XCTAssertEqualWithAccuracy([[points lastObject] pointValue].x, 100, 0.01);
}

- (void)testManyIsTheFoot
{
	DKRecordingSurface *surface = DKDrawn(DKEdgeEndCrowFootMany);
	NSArray *marks = DKMarks(surface);
	XCTAssertEqual([marks count], 1u);
	DKRecordedOperation *foot = [marks firstObject];
	XCTAssertTrue(NSEqualRects(foot.rect, NSMakeRect(90, 44, 10, 12)), @"toes on the shape: %@",
	              NSStringFromRect(foot.rect));
	NSArray *points = DKPathPoints(foot.path);
	XCTAssertTrue(NSEqualPoints([[points objectAtIndex:1] pointValue], NSMakePoint(90, 50)), @"the heel back on the line");
}

- (void)testOneOrManyAndZeroOrMany
{
	NSArray *marks = DKMarks(DKDrawn(DKEdgeEndCrowFootOneOrMany));
	XCTAssertEqual([marks count], 2u);
	XCTAssertTrue(NSEqualRects([[marks firstObject] rect], NSMakeRect(90, 44, 10, 12)));
	XCTAssertTrue(DKIsBarAt([marks lastObject], 86), @"%@", NSStringFromRect([[marks lastObject] rect]));

	DKRecordingSurface *zero = DKDrawn(DKEdgeEndCrowFootZeroOrMany);
	marks = DKMarks(zero);
	XCTAssertEqual([marks count], 2u);
	DKRecordedOperation *circle = [marks lastObject];
	XCTAssertEqual(circle.path.shape, DKPathShapeOval);
	XCTAssertGreaterThan(100 - NSMaxX(circle.rect), 10.0, @"beyond the foot");
	XCTAssertEqual(DKPathMoves(DKLine(zero).path), 2u);
}

/* The ends point the way the route goes at each end: a route up the
 * page ends in a foot pointing up; a start's mark points back. */
- (void)testEndsFollowTheirSegment
{
	DKRecordingSurface *surface = [[DKRecordingSurface alloc] init];
	DKDrawRoute(surface, @[ DKP(50, 200), DKP(50, 100), DKP(150, 100), DKP(150, 0) ], DKColorBlack(), 1, DKStrokeDashed,
	            DKEdgeEndCrowFootMany, DKEdgeEndCrowFootMany);
	NSArray *strokes = [surface operationsOfKind:DKRecordedStroke];
	XCTAssertEqual([strokes count], 3u);
	XCTAssertEqual([[strokes firstObject] strokeStyle], DKStrokeDashed, @"the line dashed");
	XCTAssertEqual([[strokes objectAtIndex:1] strokeStyle], DKStrokeSolid, @"the marks not");
	XCTAssertTrue(NSEqualRects([[strokes objectAtIndex:1] rect], NSMakeRect(44, 190, 12, 10)), @"start: %@",
	              NSStringFromRect([[strokes objectAtIndex:1] rect]));
	XCTAssertTrue(NSEqualRects([[strokes objectAtIndex:2] rect], NSMakeRect(144, 0, 12, 10)), @"end: %@",
	              NSStringFromRect([[strokes objectAtIndex:2] rect]));
	/* Repeated points do not turn it. */
	DKRecordingSurface *repeated = [[DKRecordingSurface alloc] init];
	DKDrawRoute(repeated, @[ DKP(0, 50), DKP(100, 50), DKP(100, 50) ], DKColorBlack(), 1, DKStrokeSolid, DKEdgeEndNone,
	            DKEdgeEndCrowFootMany);
	XCTAssertTrue(NSEqualRects([[DKMarks(repeated) firstObject] rect], NSMakeRect(90, 44, 10, 12)));
	DKRecordingSurface *empty = [[DKRecordingSurface alloc] init];
	DKDrawRoute(empty, @[ DKP(5, 5) ], DKColorBlack(), 1, DKStrokeSolid, DKEdgeEndArrow, DKEdgeEndArrow);
	XCTAssertEqual([empty.operations count], 0u);
}

- (void)testMarksGrowWithTheWidth
{
	DKRecordingSurface *surface = [[DKRecordingSurface alloc] init];
	DKDrawRoute(surface, @[ DKP(0, 50), DKP(100, 50) ], DKColorBlack(), 2, DKStrokeSolid, DKEdgeEndNone, DKEdgeEndCrowFootMany);
	XCTAssertTrue(NSEqualRects([[DKMarks(surface) firstObject] rect], NSMakeRect(80, 38, 20, 24)));
	XCTAssertEqualWithAccuracy(DKEdgeEndLength(DKEdgeEndCrowFootMany, 2), 20, 0.01);
	XCTAssertEqualWithAccuracy(DKEdgeEndLength(DKEdgeEndCrowFootOne, 1), 12, 0.01);
	XCTAssertEqual(DKEdgeEndLength(DKEdgeEndNone, 1), 0.0);
}

@end
