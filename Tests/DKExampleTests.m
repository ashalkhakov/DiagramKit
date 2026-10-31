/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKit/DiagramKit.h>
#import "DKExampleDiagram.h"

/* The example diagram, drawn as SVG: the README's picture. Written to
 * DK_EXAMPLE_SVG when it is set, else to the temporary folder. */
@interface DKExampleTests : XCTestCase
@end

@implementation DKExampleTests

- (void)testTheShopsSchemaAsSVG
{
	DKExampleDiagram *diagram = [DKExampleDiagram shop];
	NSRect bounds = diagram.bounds;
	DKSVGSurface *surface = [[DKSVGSurface alloc] initWithBounds:bounds];
	surface.title = @"A shop's schema";
	surface.background = DKColorWhite();
	DKDrawingState *state = [[DKDrawingState alloc] init];
	state.forPrinting = YES;
	[diagram drawOn:surface state:state];
	NSString *svg = [surface SVGString];
	for (NSString *table in diagram.tables) {
		NSString *text = [NSString stringWithFormat:@">%@</text>", table];
		XCTAssertTrue([svg rangeOfString:text].location != NSNotFound, @"%@", table);
	}
	/* Laid out top to bottom: what is referred to above what refers to it. */
	XCTAssertLessThan(NSMaxY([diagram frameOfTable:@"customers"]), NSMinY([diagram frameOfTable:@"orders"]));
	XCTAssertLessThan(NSMaxY([diagram frameOfTable:@"orders"]), NSMinY([diagram frameOfTable:@"order_lines"]));
	NSString *path = [[[NSProcessInfo processInfo] environment] objectForKey:@"DK_EXAMPLE_SVG"];
	if ([path length] == 0) {
		path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"DiagramKit-example.svg"];
	}
	NSError *error = nil;
	XCTAssertTrue([svg writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
}

@end
