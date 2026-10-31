/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKit/DiagramKit.h>

/* The force-directed layout: the same every time, nothing overlapping,
 * springs pulling, fixed nodes staying. */
@interface DKForceLayoutTests : XCTestCase
@end

@implementation DKForceLayoutTests

/* A schema's tables: a star round orders, and two alone. */
static DKForceLayout *
DKSchemaLayout(BOOL fixOrders)
{
	DKForceLayout *layout = [[DKForceLayout alloc] init];
	NSArray *tables = @[ @"orders", @"customers", @"products", @"lines", @"payments", @"audit", @"settings" ];
	for (NSUInteger i = 0; i < [tables count]; i++) {
		NSString *table = [tables objectAtIndex:i];
		NSValue *origin = fixOrders && i == 0 ? [NSValue valueWithPoint:NSMakePoint(400, 300)] : nil;
		[layout addNode:table size:NSMakeSize(90 + 10 * (i % 3), 50 + 15 * (i % 4)) fixedAt:origin];
	}
	for (NSString *other in @[ @"customers", @"products", @"lines", @"payments" ]) {
		[layout addSpringFrom:@"orders" to:other length:120];
	}
	[layout addSpringFrom:@"lines" to:@"products" length:100];
	return layout;
}

static BOOL
DKAnyOverlap(NSDictionary *frames, NSString **which)
{
	NSArray *keys = [[frames allKeys] sortedArrayUsingSelector:@selector(compare:)];
	for (NSUInteger i = 0; i < [keys count]; i++) {
		for (NSUInteger j = i + 1; j < [keys count]; j++) {
			if (NSIntersectsRect([[frames objectForKey:[keys objectAtIndex:i]] rectValue],
			                     [[frames objectForKey:[keys objectAtIndex:j]] rectValue])) {
				*which = [NSString stringWithFormat:@"%@ and %@", [keys objectAtIndex:i], [keys objectAtIndex:j]];
				return YES;
			}
		}
	}
	return NO;
}

- (void)testItIsDeterministic
{
	NSDictionary *first = [DKSchemaLayout(NO) layout];
	NSDictionary *second = [DKSchemaLayout(NO) layout];
	XCTAssertEqual([first count], 7u);
	XCTAssertEqualObjects(first, second);
}

- (void)testNothingOverlaps
{
	NSString *which = nil;
	NSDictionary *frames = [DKSchemaLayout(NO) layout];
	XCTAssertFalse(DKAnyOverlap(frames, &which), @"%@", which);
	/* Many of one size, crowded by short springs. */
	DKForceLayout *crowd = [[DKForceLayout alloc] init];
	for (NSUInteger i = 0; i < 20; i++) {
		[crowd addNode:[NSString stringWithFormat:@"n%02lu", (unsigned long)i] size:NSMakeSize(80, 40) fixedAt:nil];
		if (i > 0) {
			[crowd addSpringFrom:@"n00" to:[NSString stringWithFormat:@"n%02lu", (unsigned long)i] length:10];
		}
	}
	XCTAssertFalse(DKAnyOverlap([crowd layout], &which), @"%@", which);
}

- (void)testTheLayoutStartsAtTheMargin
{
	DKForceLayout *layout = DKSchemaLayout(NO);
	NSDictionary *frames = [layout layout];
	double minX = 1e9, minY = 1e9;
	for (NSValue *frame in [frames allValues]) {
		minX = MIN(minX, NSMinX([frame rectValue]));
		minY = MIN(minY, NSMinY([frame rectValue]));
		XCTAssertEqual(NSMinX([frame rectValue]), round(NSMinX([frame rectValue])), @"whole points");
	}
	XCTAssertEqualWithAccuracy(minX, layout.margin, 0.5);
	XCTAssertEqualWithAccuracy(minY, layout.margin, 0.5);
}

- (void)testSpringsPullTogether
{
	NSDictionary *frames = [DKSchemaLayout(NO) layout];
	NSRect orders = [[frames objectForKey:@"orders"] rectValue];
	NSRect lines = [[frames objectForKey:@"lines"] rectValue];
	NSRect audit = [[frames objectForKey:@"audit"] rectValue];
	double linked = hypot(NSMidX(orders) - NSMidX(lines), NSMidY(orders) - NSMidY(lines));
	XCTAssertLessThan(linked, 220.0, @"a spring's ends settle near its length");
	XCTAssertGreaterThan(hypot(NSMidX(audit) - NSMidX(lines), NSMidY(audit) - NSMidY(lines)), 0.0);
}

- (void)testAFixedNodeStaysAndTheRestGoRoundIt
{
	DKForceLayout *layout = DKSchemaLayout(YES);
	NSDictionary *frames = [layout layout];
	NSRect orders = [[frames objectForKey:@"orders"] rectValue];
	XCTAssertTrue(NSEqualPoints(orders.origin, NSMakePoint(400, 300)));
	NSString *which = nil;
	XCTAssertFalse(DKAnyOverlap(frames, &which), @"%@", which);
	NSRect customers = [[frames objectForKey:@"customers"] rectValue];
	XCTAssertLessThan(hypot(NSMidX(orders) - NSMidX(customers), NSMidY(orders) - NSMidY(customers)), 400.0,
	                  @"laid out about the fixed node");
	XCTAssertEqualObjects(frames, [DKSchemaLayout(YES) layout]);
}

- (void)testNoNodesNoFrames
{
	XCTAssertEqual([[[[DKForceLayout alloc] init] layout] count], 0u);
}

@end
