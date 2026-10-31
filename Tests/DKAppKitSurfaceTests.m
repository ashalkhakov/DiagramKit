/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKitUI/DiagramKitUI.h>

/* AppKit's measure of text wrapped to a width: what -drawText:inRect: sets
 * in that width, so a box can centre it. */
@interface DKAppKitSurfaceTests : XCTestCase
@end

@implementation DKAppKitSurfaceTests

- (void)setUp
{
	[super setUp];
	[NSApplication sharedApplication];
}

- (void)testWrappedTextIsMeasured
{
	DKAppKitSurface *surface = [DKAppKitSurface surface];
	DKFont *font = [DKFont systemFontOfSize:12 bold:NO];
	NSString *text = @"Check the customer's order before it ships";
	NSSize line = [surface sizeOfText:text font:font];
	NSSize wide = [surface sizeOfText:text font:font wrappedToWidth:1000];
	XCTAssertEqualWithAccuracy(wide.height, line.height, 1.5, @"one line where it fits");
	NSSize narrow = [surface sizeOfText:text font:font wrappedToWidth:80];
	XCTAssertLessThanOrEqual(narrow.width, 80.0);
	XCTAssertGreaterThan(narrow.height, 2.5 * line.height, @"wrapped: %@ vs a line %@", NSStringFromSize(narrow),
	                     NSStringFromSize(line));
	XCTAssertGreaterThan([surface sizeOfText:@"" font:font wrappedToWidth:80].height, 0.0, @"empty: a line's height");
}

@end
