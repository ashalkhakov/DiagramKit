/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKit/DiagramKit.h>

/* What the SVG surface writes: a document an XML parser reads, with an
 * element for each thing drawn. */
@interface DKSVGSurfaceTests : XCTestCase <NSXMLParserDelegate>
@end

@implementation DKSVGSurfaceTests
{
	NSMutableArray<NSString *> *_elements;
	NSMutableArray<NSDictionary *> *_attributes;
	NSMutableString *_text;
}

- (void)parser:(NSXMLParser *)parser
    didStartElement:(NSString *)name
       namespaceURI:(NSString *)namespaceURI
      qualifiedName:(NSString *)qualifiedName
         attributes:(NSDictionary *)attributes
{
	[_elements addObject:name];
	[_attributes addObject:attributes];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[_text appendString:string];
}

/* The document parsed: its elements and their attributes, in order. */
- (BOOL)parse:(NSString *)svg
{
	_elements = [NSMutableArray array];
	_attributes = [NSMutableArray array];
	_text = [NSMutableString string];
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[svg dataUsingEncoding:NSUTF8StringEncoding]];
	[parser setDelegate:self];
	return [parser parse];
}

- (NSDictionary *)attributesOf:(NSString *)element
{
	NSUInteger index = [_elements indexOfObject:element];
	return index != NSNotFound ? [_attributes objectAtIndex:index] : nil;
}

- (void)testADocumentWithThePathsAndText
{
	DKSVGSurface *surface = [[DKSVGSurface alloc] initWithSize:NSMakeSize(300, 200)];
	surface.title = @"Orders & <Lines>";
	surface.background = DKColorWhite();
	[surface fillPath:[DKPath pathWithRect:NSMakeRect(10, 20, 100, 50)] color:DKColorMake(0.9, 0.9, 1, 1)];
	[surface strokePath:[DKPath pathWithRoundedRect:NSMakeRect(10, 20, 100, 50) radius:6] color:DKColorBlack() width:1
	             dashed:NO];
	[surface strokePath:[DKPath pathWithOvalInRect:NSMakeRect(150, 20, 40, 20)] color:DKColorBlack() width:1 dashed:YES];
	DKPath *line = [DKPath pathWithPoints:@[ [NSValue valueWithPoint:NSMakePoint(110, 45)],
	                                         [NSValue valueWithPoint:NSMakePoint(130, 45)],
	                                         [NSValue valueWithPoint:NSMakePoint(130, 100)] ]];
	[surface strokePath:line color:DKColorWithAlpha(DKColorBlack(), 0.5) width:1.5 dashed:NO];
	DKFont *font = [DKFont systemFontOfSize:10 bold:YES];
	[surface drawText:@"orders" at:NSMakePoint(60, 25) font:font color:DKColorBlack() centered:YES];
	[surface drawText:@"id integer" inRect:NSMakeRect(15, 40, 90, 30) font:[DKFont fontWithName:@"Menlo" size:9 bold:NO]
	            color:DKColorBlack()];

	NSString *svg = [surface SVGString];
	XCTAssertTrue([svg hasPrefix:@"<?xml"]);
	XCTAssertTrue([self parse:svg], @"well-formed:\n%@", svg);
	XCTAssertEqualObjects([_elements firstObject], @"svg");
	NSDictionary *root = [_attributes firstObject];
	XCTAssertEqualObjects([root objectForKey:@"viewBox"], @"0 0 300 200");
	XCTAssertEqualObjects([root objectForKey:@"xmlns"], @"http://www.w3.org/2000/svg");
	XCTAssertTrue([_text rangeOfString:@"Orders & <Lines>"].location != NSNotFound, @"the title, escaped and read back");
	XCTAssertEqual([[_elements filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'rect'"]] count], 3u,
	               @"the paper, the fill, the rounded outline");
	NSDictionary *ellipse = [self attributesOf:@"ellipse"];
	XCTAssertEqualObjects([ellipse objectForKey:@"cx"], @"170");
	XCTAssertEqualObjects([ellipse objectForKey:@"rx"], @"20");
	XCTAssertEqualObjects([ellipse objectForKey:@"stroke-dasharray"], @"2 2");
	NSDictionary *path = [self attributesOf:@"path"];
	XCTAssertEqualObjects([path objectForKey:@"d"], @"M110 45 L130 45 L130 100");
	XCTAssertEqualObjects([path objectForKey:@"stroke-opacity"], @"0.5");
	XCTAssertEqualObjects([path objectForKey:@"stroke-width"], @"1.5");
	NSDictionary *text = [self attributesOf:@"text"];
	XCTAssertEqualObjects([text objectForKey:@"text-anchor"], @"middle");
	XCTAssertEqualObjects([text objectForKey:@"font-weight"], @"bold");
	XCTAssertEqualObjects([text objectForKey:@"y"], @"35", @"the baseline an em below the top");
	XCTAssertTrue([_text rangeOfString:@"orders"].location != NSNotFound);
	XCTAssertTrue([_text rangeOfString:@"id integer"].location != NSNotFound);
	XCTAssertTrue([svg rangeOfString:@"'Menlo'"].location != NSNotFound);
}

- (void)testCurvesAndBounds
{
	DKSVGSurface *surface = [[DKSVGSurface alloc] initWithBounds:NSMakeRect(-10, -20, 100, 50)];
	DKPath *curve = [DKPath path];
	[curve moveTo:NSMakePoint(0, 0)];
	[curve curveTo:NSMakePoint(10, 0) control1:NSMakePoint(0, 10) control2:NSMakePoint(10, 10)];
	[curve close];
	[surface fillPath:curve color:DKColorBlack()];
	NSString *svg = [surface SVGString];
	XCTAssertTrue([self parse:svg], @"%@", svg);
	XCTAssertEqualObjects([[_attributes firstObject] objectForKey:@"viewBox"], @"-10 -20 100 50");
	XCTAssertEqualObjects([[self attributesOf:@"path"] objectForKey:@"d"], @"M0 0 C0 10 10 10 10 0 Z");
	XCTAssertNil([self attributesOf:@"rect"], @"no paper unless given");
}

- (void)testTextIsMeasuredByItsSize
{
	DKSVGSurface *surface = [[DKSVGSurface alloc] initWithSize:NSMakeSize(10, 10)];
	NSSize small = [surface sizeOfText:@"customer_id" font:[DKFont systemFontOfSize:10 bold:NO]];
	NSSize large = [surface sizeOfText:@"customer_id" font:[DKFont systemFontOfSize:20 bold:NO]];
	XCTAssertGreaterThan(small.width, 30.0);
	XCTAssertEqualWithAccuracy(large.width, small.width * 2, 0.001);
	XCTAssertGreaterThan([surface sizeOfText:@"WWW" font:[DKFont systemFontOfSize:10 bold:NO]].width,
	                     [surface sizeOfText:@"iii" font:[DKFont systemFontOfSize:10 bold:NO]].width);
}

- (void)testWrappedTextStopsAtTheRectanglesHeight
{
	DKSVGSurface *surface = [[DKSVGSurface alloc] initWithSize:NSMakeSize(100, 100)];
	[surface drawText:@"one two three four five six seven eight nine ten" inRect:NSMakeRect(0, 0, 40, 25)
	             font:[DKFont systemFontOfSize:10 bold:NO]
	            color:DKColorBlack()];
	XCTAssertTrue([self parse:[surface SVGString]]);
	XCTAssertEqual([[_elements filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'text'"]] count], 2u,
	               @"two lines of 12.1 points fit 25");
}

@end
