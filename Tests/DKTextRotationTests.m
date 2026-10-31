/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKitUI/DiagramKitUI.h>
#import "DKRecordingSurface.h"

/* Text turned a quarter (a BPMN lane's name): written to SVG as a rotation
 * about its centre, and drawn by AppKit -- the canvas's PNG, read back --
 * running up or down the page, its first letters where its reading starts.
 * The test is the canvas's data source: one line, heavy first ("MMMMM",
 * then dots), centred on the diagram. */
@interface DKTextRotationTests : XCTestCase <DKCanvasDataSource>
@end

@implementation DKTextRotationTests
{
	DKTextRotation _rotation;
}

static NSString *const DKLine = @"MMMMM..........";
static const NSRect DKBounds = { { 0, 0 }, { 240, 240 } };

- (void)setUp
{
	[super setUp];
	[NSApplication sharedApplication];
}

- (NSRect)diagramBoundsForCanvas:(DKCanvasView *)canvas
{
	return DKBounds;
}

- (void)canvas:(DKCanvasView *)canvas drawInRect:(NSRect)rect surface:(id<DKSurface>)surface state:(DKDrawingState *)state
{
	[surface drawText:DKLine centeredAt:NSMakePoint(NSMidX(DKBounds), NSMidY(DKBounds))
	             font:[DKFont systemFontOfSize:18 bold:YES] color:DKColorBlack() rotation:_rotation];
}

- (id)canvas:(DKCanvasView *)canvas itemAtPoint:(NSPoint)point
{
	return nil;
}

- (NSArray *)canvas:(DKCanvasView *)canvas itemsInRect:(NSRect)rect
{
	return @[];
}

- (NSRect)canvas:(DKCanvasView *)canvas frameOfItem:(id)item
{
	return NSZeroRect;
}

/* The canvas's PNG of the line turned so; the ink's bounds (image rows:
 * top down, as the diagram's y) and how much of it is in each half. */
- (NSRect)inkTurned:(DKTextRotation)rotation first:(NSUInteger *)first second:(NSUInteger *)second vertical:(BOOL)vertical
{
	_rotation = rotation;
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 300) styleMask:NSWindowStyleMaskTitled
	                                                 backing:NSBackingStoreBuffered defer:YES];
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 300)];
	DKCanvasView *canvas = [[DKCanvasView alloc] initWithFrame:NSMakeRect(0, 0, 300, 300)];
	[scroll setDocumentView:canvas];
	[window setContentView:scroll];
	canvas.dataSource = self;
	canvas.margin = 0;
	[canvas reloadData];
	NSBitmapImageRep *image = [NSBitmapImageRep imageRepWithData:[canvas PNGDataAtScale:1.0]];
	NSInteger width = [image pixelsWide], height = [image pixelsHigh];
	NSInteger minX = width, minY = height, maxX = -1, maxY = -1;
	*first = 0;
	*second = 0;
	for (NSInteger y = 0; y < height; y++) {
		for (NSInteger x = 0; x < width; x++) {
			NSColor *color = [[image colorAtX:x y:y] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
			if ([color brightnessComponent] > 0.5 || [color alphaComponent] < 0.5) {
				continue;
			}
			minX = MIN(minX, x), maxX = MAX(maxX, x), minY = MIN(minY, y), maxY = MAX(maxY, y);
			if ((vertical ? y : x) < (vertical ? height : width) / 2) {
				(*first)++;
			} else {
				(*second)++;
			}
		}
	}
	return maxX < 0 ? NSZeroRect : NSMakeRect(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

- (void)testAppKitTurnsItAQuarter
{
	NSUInteger top, bottom, left, right;
	NSRect level = [self inkTurned:DKTextRotationNone first:&left second:&right vertical:NO];
	XCTAssertGreaterThan(NSWidth(level), 2 * NSHeight(level), @"level: %@", NSStringFromRect(level));
	XCTAssertGreaterThan(left, right, @"MMMMM first, at the left");
	XCTAssertEqualWithAccuracy(NSMidX(level), NSMidX(DKBounds), 6, @"centred");

	NSRect up = [self inkTurned:DKTextRotationQuarterAnticlockwise first:&top second:&bottom vertical:YES];
	XCTAssertGreaterThan(NSHeight(up), 2 * NSWidth(up), @"anticlockwise: %@", NSStringFromRect(up));
	XCTAssertGreaterThan(bottom, top, @"read bottom to top: MMMMM at the bottom");
	XCTAssertEqualWithAccuracy(NSMidY(up), NSMidY(DKBounds), 6, @"centred");
	XCTAssertEqualWithAccuracy(NSMidX(up), NSMidX(DKBounds), 6);

	NSRect down = [self inkTurned:DKTextRotationQuarterClockwise first:&top second:&bottom vertical:YES];
	XCTAssertGreaterThan(NSHeight(down), 2 * NSWidth(down), @"clockwise: %@", NSStringFromRect(down));
	XCTAssertGreaterThan(top, bottom, @"read top to bottom: MMMMM at the top");
}

- (void)testSVGRotatesAboutTheCentre
{
	DKSVGSurface *surface = [[DKSVGSurface alloc] initWithSize:NSMakeSize(100, 200)];
	DKFont *font = [DKFont systemFontOfSize:10 bold:NO];
	[surface drawText:@"Lane & pool" centeredAt:NSMakePoint(20, 100) font:font color:DKColorBlack()
	         rotation:DKTextRotationQuarterAnticlockwise];
	[surface drawText:@"down" centeredAt:NSMakePoint(80, 100) font:font color:DKColorBlack()
	         rotation:DKTextRotationQuarterClockwise];
	[surface drawText:@"level" centeredAt:NSMakePoint(50, 10) font:font color:DKColorBlack() rotation:DKTextRotationNone];
	NSString *svg = [surface SVGString];
	/* Centred both ways: the anchor the middle, the baseline half a line
	 * below the point's line top. */
	NSString *baseline = [NSString stringWithFormat:@"%g", 100 - [surface sizeOfText:@"x" font:font].height / 2 + 10];
	NSString *expected = [NSString stringWithFormat:@"<text x=\"20\" y=\"%@\"", baseline];
	XCTAssertTrue([svg rangeOfString:expected].location != NSNotFound, @"%@ in\n%@", expected, svg);
	XCTAssertTrue([svg rangeOfString:@"transform=\"rotate(-90 20 100)\" xml:space=\"preserve\">Lane &amp; pool</text>"].location
	              != NSNotFound, @"%@", svg);
	XCTAssertTrue([svg rangeOfString:@"transform=\"rotate(90 80 100)\""].location != NSNotFound);
	NSRange level = [svg rangeOfString:@">level</text>"];
	XCTAssertTrue(level.location != NSNotFound);
	NSRange line = [svg lineRangeForRange:level];
	XCTAssertTrue([[svg substringWithRange:line] rangeOfString:@"transform"].location == NSNotFound, @"none: not turned");
	XCTAssertTrue([[svg substringWithRange:line] rangeOfString:@"text-anchor=\"middle\""].location != NSNotFound);
}

- (void)testARecordingKeepsTheTurn
{
	DKRecordingSurface *surface = [[DKRecordingSurface alloc] init];
	[surface drawText:@"Pool" centeredAt:NSMakePoint(5, 6) font:[DKFont systemFontOfSize:10 bold:NO] color:DKColorBlack()
	         rotation:DKTextRotationQuarterAnticlockwise];
	DKRecordedOperation *text = [[surface operationsOfKind:DKRecordedText] firstObject];
	XCTAssertTrue(text.centeredAt);
	XCTAssertEqual(text.rotation, DKTextRotationQuarterAnticlockwise);
	XCTAssertTrue(NSEqualPoints(text.rect.origin, NSMakePoint(5, 6)));
}

@end
