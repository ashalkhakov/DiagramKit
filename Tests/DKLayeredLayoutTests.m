/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKit/DiagramKit.h>

/* The layered layout: UDWorkflow's cases, and both directions. */
@interface DKLayeredLayoutTests : XCTestCase
@end

@implementation DKLayeredLayoutTests

static NSRect
DKFrame(NSDictionary *frames, NSString *identifier)
{
	return [[frames objectForKey:identifier] rectValue];
}

- (void)assertNoOverlaps:(NSDictionary *)frames
{
	NSArray *keys = [[frames allKeys] sortedArrayUsingSelector:@selector(compare:)];
	for (NSUInteger i = 0; i < [keys count]; i++) {
		for (NSUInteger j = i + 1; j < [keys count]; j++) {
			NSRect a = DKFrame(frames, [keys objectAtIndex:i]), b = DKFrame(frames, [keys objectAtIndex:j]);
			XCTAssertFalse(NSIntersectsRect(a, b), @"%@ %@ overlaps %@ %@", [keys objectAtIndex:i], NSStringFromRect(a),
			               [keys objectAtIndex:j], NSStringFromRect(b));
		}
	}
}

- (void)testFramesHaveTheNodesSizes
{
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	[layout addNode:@"a" size:NSMakeSize(36, 36)];
	[layout addNode:@"b" size:NSMakeSize(100, 80)];
	[layout addEdgeFrom:@"a" to:@"b"];
	NSDictionary *frames = [layout layout];
	XCTAssertTrue(NSEqualSizes(DKFrame(frames, @"a").size, NSMakeSize(36, 36)));
	XCTAssertTrue(NSEqualSizes(DKFrame(frames, @"b").size, NSMakeSize(100, 80)));
	XCTAssertEqual(NSMinX(DKFrame(frames, @"a")), 0.0);
	XCTAssertEqual(NSMinY(DKFrame(frames, @"b")), 0.0, @"from the top left");
}

- (void)testAChainIsOneStraightLine
{
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	[layout addNode:@"a" size:NSMakeSize(36, 36)];
	[layout addNode:@"b" size:NSMakeSize(100, 80)];
	[layout addNode:@"c" size:NSMakeSize(36, 36)];
	[layout addEdgeFrom:@"a" to:@"b"];
	[layout addEdgeFrom:@"b" to:@"c"];
	NSDictionary *frames = [layout layout];
	NSRect a = DKFrame(frames, @"a"), b = DKFrame(frames, @"b"), c = DKFrame(frames, @"c");
	XCTAssertEqual(NSMidY(a), NSMidY(b));
	XCTAssertEqual(NSMidY(b), NSMidY(c));
	XCTAssertEqual(NSMinX(b) - NSMaxX(a), layout.layerSpacing);
	XCTAssertLessThan(NSMaxX(b), NSMinX(c));
	XCTAssertEqual(layout.size.height, 80.0);
}

- (void)testBranchesShareALayerWithoutOverlapping
{
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	for (NSString *node in @[ @"split", @"x", @"y", @"z", @"join" ]) {
		[layout addNode:node size:NSMakeSize(100, 80)];
	}
	for (NSString *branch in @[ @"x", @"y", @"z" ]) {
		[layout addEdgeFrom:@"split" to:branch];
		[layout addEdgeFrom:branch to:@"join"];
	}
	NSDictionary *frames = [layout layout];
	XCTAssertEqual([layout layerOf:@"x"], 1);
	XCTAssertEqual([layout layerOf:@"z"], 1);
	XCTAssertEqual([layout layerOf:@"join"], 2);
	NSRect x = DKFrame(frames, @"x"), y = DKFrame(frames, @"y");
	XCTAssertEqual(NSMinY(y) - NSMaxY(x), layout.nodeSpacing);
	XCTAssertEqual(NSMidY(DKFrame(frames, @"split")), NSMidY(y), @"centred on its branches");
	[self assertNoOverlaps:frames];
}

- (void)testABranchBelowHangsBelow
{
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	NSSize big = NSMakeSize(300, 230), task = NSMakeSize(100, 80);
	[layout addNode:@"start" size:NSMakeSize(36, 36)];
	[layout addNode:@"work" size:big];
	[layout addNode:@"late" size:task];
	[layout addNode:@"next" size:task];
	[layout addNode:@"join" size:NSMakeSize(50, 50)];
	[layout addEdgeFrom:@"start" to:@"work"];
	[layout addEdgeFrom:@"work" to:@"next"];
	[layout addEdgeFrom:@"work" to:@"late" below:YES];
	[layout addEdgeFrom:@"late" to:@"join"];
	[layout addEdgeFrom:@"next" to:@"join"];
	NSDictionary *frames = [layout layout];
	NSRect work = DKFrame(frames, @"work"), late = DKFrame(frames, @"late"), next = DKFrame(frames, @"next");
	XCTAssertGreaterThan(NSMinY(late), NSMaxY(work));
	XCTAssertGreaterThan(NSMinY(late), NSMaxY(next));
	XCTAssertEqual(NSMidY(next), NSMidY(work));
}

/* A cycle: laid out as if it ran forward, the edge closing it reversed;
 * every node still placed once, and nothing overlapping. */
- (void)testACycleIsLaidOutAsIfItRanForward
{
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	for (NSString *node in @[ @"start", @"work", @"check", @"end" ]) {
		[layout addNode:node size:NSMakeSize(50, 50)];
	}
	[layout addEdgeFrom:@"start" to:@"work"];
	[layout addEdgeFrom:@"work" to:@"check"];
	[layout addEdgeFrom:@"check" to:@"work"];
	[layout addEdgeFrom:@"check" to:@"end"];
	NSDictionary *frames = [layout layout];
	XCTAssertEqual([frames count], 4u);
	XCTAssertEqual([layout layerOf:@"start"], 0);
	XCTAssertEqual([layout layerOf:@"work"], 1);
	XCTAssertEqual([layout layerOf:@"check"], 2);
	XCTAssertEqual([layout layerOf:@"end"], 3);
	[self assertNoOverlaps:frames];
}

- (void)testACycleWithNoWayInStartsAtTheFirstNode
{
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	for (NSString *node in @[ @"a", @"b", @"c" ]) {
		[layout addNode:node size:NSMakeSize(40, 40)];
	}
	[layout addEdgeFrom:@"a" to:@"b"];
	[layout addEdgeFrom:@"b" to:@"c"];
	[layout addEdgeFrom:@"c" to:@"a"];
	NSDictionary *frames = [layout layout];
	XCTAssertEqual([frames count], 3u);
	XCTAssertEqual([layout layerOf:@"a"], 0);
	XCTAssertEqual([layout layerOf:@"c"], 2);
	[self assertNoOverlaps:frames];
}

- (void)testALongEdgeGoesThroughPlaceholders
{
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	for (NSString *node in @[ @"a", @"b", @"c", @"d", @"e" ]) {
		[layout addNode:node size:NSMakeSize(40, 40)];
	}
	[layout addEdgeFrom:@"a" to:@"b"];
	[layout addEdgeFrom:@"b" to:@"c"];
	[layout addEdgeFrom:@"c" to:@"d"];
	[layout addEdgeFrom:@"a" to:@"e"];
	[layout addEdgeFrom:@"e" to:@"d"];
	NSDictionary *frames = [layout layout];
	XCTAssertEqual([frames count], 5u, @"placeholders are not nodes");
	XCTAssertEqual([layout layerOf:@"d"], 3);
	XCTAssertEqual([layout layerOf:@"e"], 1);
	[self assertNoOverlaps:frames];
	XCTAssertEqual([layout layerOf:@"nothing"], -1);
}

/* Every edge points forward, in either direction; no two nodes overlap;
 * the extent holds every frame. */
- (void)checkEdgesPointForward:(DKLayoutDirection)direction
{
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	layout.direction = direction;
	NSArray *edges = @[ @[ @"customer", @"order" ], @[ @"order", @"line" ], @[ @"product", @"line" ],
		@[ @"category", @"product" ], @[ @"customer", @"address" ], @[ @"order", @"shipment" ],
		@[ @"address", @"shipment" ] ];
	NSArray *nodes = @[ @"customer", @"order", @"line", @"product", @"category", @"address", @"shipment" ];
	for (NSUInteger i = 0; i < [nodes count]; i++) {
		[layout addNode:[nodes objectAtIndex:i] size:NSMakeSize(80 + 10 * i, 40 + 7 * i)];
	}
	for (NSArray *edge in edges) {
		[layout addEdgeFrom:[edge objectAtIndex:0] to:[edge objectAtIndex:1]];
	}
	NSDictionary *frames = [layout layout];
	XCTAssertEqual([frames count], [nodes count]);
	[self assertNoOverlaps:frames];
	for (NSArray *edge in edges) {
		NSRect source = DKFrame(frames, [edge objectAtIndex:0]), target = DKFrame(frames, [edge objectAtIndex:1]);
		if (direction == DKLayoutLeftToRight) {
			XCTAssertLessThan(NSMaxX(source), NSMinX(target), @"%@", edge);
		} else {
			XCTAssertLessThan(NSMaxY(source), NSMinY(target), @"%@", edge);
		}
		XCTAssertLessThan([layout layerOf:[edge objectAtIndex:0]], [layout layerOf:[edge objectAtIndex:1]]);
	}
	for (NSValue *frame in [frames allValues]) {
		XCTAssertGreaterThanOrEqual(NSMinX([frame rectValue]), -0.5);
		XCTAssertGreaterThanOrEqual(NSMinY([frame rectValue]), -0.5);
		XCTAssertLessThanOrEqual(NSMaxX([frame rectValue]), layout.size.width + 0.5);
		XCTAssertLessThanOrEqual(NSMaxY([frame rectValue]), layout.size.height + 0.5);
	}
}

- (void)testEdgesPointRightLeftToRight
{
	[self checkEdgesPointForward:DKLayoutLeftToRight];
}

- (void)testEdgesPointDownTopToBottom
{
	[self checkEdgesPointForward:DKLayoutTopToBottom];
}

- (void)testTopToBottomIsLeftToRightTransposed
{
	DKLayeredLayout *across = [[DKLayeredLayout alloc] init];
	DKLayeredLayout *down = [[DKLayeredLayout alloc] init];
	down.direction = DKLayoutTopToBottom;
	for (DKLayeredLayout *layout in @[ across, down ]) {
		BOOL transposed = layout == down;
		for (NSString *node in @[ @"split", @"x", @"y", @"join" ]) {
			[layout addNode:node size:transposed ? NSMakeSize(60, 100) : NSMakeSize(100, 60)];
		}
		[layout addEdgeFrom:@"split" to:@"x"];
		[layout addEdgeFrom:@"split" to:@"y"];
		[layout addEdgeFrom:@"x" to:@"join"];
		[layout addEdgeFrom:@"y" to:@"join"];
	}
	NSDictionary *a = [across layout], *b = [down layout];
	for (NSString *node in @[ @"split", @"x", @"y", @"join" ]) {
		NSRect r = DKFrame(a, node), t = DKFrame(b, node);
		XCTAssertEqual(NSMinX(r), NSMinY(t), @"%@", node);
		XCTAssertEqual(NSMinY(r), NSMinX(t), @"%@", node);
	}
	XCTAssertEqual(across.size.width, down.size.height);
	XCTAssertEqual(across.size.height, down.size.width);
}

- (void)testTheSameGraphComesOutTheSame
{
	NSDictionary *first = nil;
	for (NSUInteger run = 0; run < 2; run++) {
		DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
		for (NSUInteger i = 0; i < 12; i++) {
			[layout addNode:[NSString stringWithFormat:@"n%lu", (unsigned long)i] size:NSMakeSize(50, 30)];
		}
		for (NSUInteger i = 0; i < 12; i++) {
			[layout addEdgeFrom:[NSString stringWithFormat:@"n%lu", (unsigned long)(i / 3)]
			                 to:[NSString stringWithFormat:@"n%lu", (unsigned long)(i + 1) % 12]];
		}
		NSDictionary *frames = [layout layout];
		if (first == nil) {
			first = frames;
		} else {
			XCTAssertEqualObjects(frames, first);
		}
	}
}

@end
