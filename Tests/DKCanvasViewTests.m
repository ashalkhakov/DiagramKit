/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import <XCTest/XCTest.h>
#import <DiagramKitUI/DiagramKitUI.h>
#import "DKExampleDiagram.h"

/* The canvas driven as a user would, by synthesized events: clicks and
 * bands select, a drag moves once, keys nudge, the zoom keeps diagram
 * points, export. The window is real; it is never shown. The test is the
 * canvas's data source (the shop's schema) and its delegate. */
@interface DKCanvasViewTests : XCTestCase <DKCanvasDataSource, DKCanvasDelegate>
@end

@implementation DKCanvasViewTests
{
	NSWindow *_window;
	NSScrollView *_scroll;
	DKCanvasView *_canvas;
	DKExampleDiagram *_diagram;
	NSMutableArray<NSArray *> *_moves;
	NSUInteger _selectionChanges;
	NSMutableArray *_doubleClicked;
	NSMutableArray *_edits;
	NSMenu *_menu;
	id _menuItem;
	/* A tool the test is: presses taken while it is on, and what they did. */
	BOOL _tool;
	NSMutableArray<NSString *> *_toolEvents;
}

- (void)setUp
{
	[super setUp];
	/* Fonts and windows need the application first, on GNUstep. */
	[NSApplication sharedApplication];
	_diagram = [DKExampleDiagram shop];
	_moves = [NSMutableArray array];
	_doubleClicked = [NSMutableArray array];
	_edits = [NSMutableArray array];
	_toolEvents = [NSMutableArray array];
	_menu = [[NSMenu alloc] initWithTitle:@"Table"];
	[_menu addItemWithTitle:@"Open" action:NULL keyEquivalent:@""];
	_window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
	                                      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable
	                                        backing:NSBackingStoreBuffered
	                                          defer:NO];
	[_window setReleasedWhenClosed:NO];
	_scroll = [[NSScrollView alloc] initWithFrame:[[_window contentView] bounds]];
	[_scroll setHasVerticalScroller:YES];
	[_scroll setHasHorizontalScroller:YES];
	_canvas = [[DKCanvasView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
	[_scroll setDocumentView:_canvas];
	[[_window contentView] addSubview:_scroll];
	_canvas.dataSource = self;
	_canvas.delegate = self;
}

- (void)tearDown
{
	[_window close];
	_window = nil;
	_canvas = nil;
	[super tearDown];
}

#pragma mark The data source and delegate

- (NSRect)diagramBoundsForCanvas:(DKCanvasView *)canvas
{
	return _diagram.bounds;
}

- (void)canvas:(DKCanvasView *)canvas drawInRect:(NSRect)rect surface:(id<DKSurface>)surface state:(DKDrawingState *)state
{
	_diagram.drawCount++;
	_diagram.lastState = state;
	[_diagram drawOn:surface state:state];
}

- (id)canvas:(DKCanvasView *)canvas itemAtPoint:(NSPoint)point
{
	for (NSString *table in [_diagram.tables reverseObjectEnumerator]) {
		if (NSPointInRect(point, [_diagram frameOfTable:table])) {
			return table;
		}
	}
	return nil;
}

- (NSArray *)canvas:(DKCanvasView *)canvas itemsInRect:(NSRect)rect
{
	NSMutableArray *items = [NSMutableArray array];
	for (NSString *table in _diagram.tables) {
		if (NSIntersectsRect(rect, [_diagram frameOfTable:table])) {
			[items addObject:table];
		}
	}
	return items;
}

- (NSRect)canvas:(DKCanvasView *)canvas frameOfItem:(id)item
{
	return [_diagram frameOfTable:item];
}

- (BOOL)canvas:(DKCanvasView *)canvas canMoveItem:(id)item
{
	return ![_diagram.locked containsObject:item];
}

- (void)canvas:(DKCanvasView *)canvas moveItems:(NSArray *)items by:(NSSize)delta
{
	[_moves addObject:@[ [items sortedArrayUsingSelector:@selector(compare:)], [NSValue valueWithSize:delta] ]];
	for (NSString *table in items) {
		[_diagram moveTable:table by:delta];
	}
	[canvas reloadData];
}

- (void)canvasSelectionDidChange:(DKCanvasView *)canvas
{
	_selectionChanges++;
}

- (void)canvas:(DKCanvasView *)canvas doubleClickedItem:(id)item
{
	[_doubleClicked addObject:item ?: [NSNull null]];
}

- (NSMenu *)canvas:(DKCanvasView *)canvas menuForItem:(id)item
{
	_menuItem = item;
	return item != nil ? _menu : nil;
}

- (void)canvas:(DKCanvasView *)canvas didEditTextOfItem:(id)item text:(NSString *)text
{
	[_edits addObject:@[ item, text ]];
}

- (BOOL)canvas:(DKCanvasView *)canvas mouseDown:(NSEvent *)event atPoint:(NSPoint)point
{
	if (_tool) {
		[_toolEvents addObject:[NSString stringWithFormat:@"down %g %g", point.x, point.y]];
	}
	return _tool;
}

- (void)canvas:(DKCanvasView *)canvas mouseDragged:(NSEvent *)event atPoint:(NSPoint)point
{
	[_toolEvents addObject:[NSString stringWithFormat:@"drag %g %g", point.x, point.y]];
}

- (void)canvas:(DKCanvasView *)canvas mouseUp:(NSEvent *)event atPoint:(NSPoint)point
{
	[_toolEvents addObject:[NSString stringWithFormat:@"up %g %g", point.x, point.y]];
}

#pragma mark Events

/* The canvas drawn now: into a bitmap on macOS, which does not draw a
 * window never shown; in its window on GNUstep, whose offscreen cache of
 * a view is empty. */
- (void)draw
{
#if defined(__APPLE__)
	NSRect visible = [_canvas visibleRect];
	NSBitmapImageRep *bitmap = [_canvas bitmapImageRepForCachingDisplayInRect:visible];
	[_canvas cacheDisplayInRect:visible toBitmapImageRep:bitmap];
#else
	[_canvas display];
#endif
}

/* A mouse event at a point of the canvas, in diagram points. */
- (NSEvent *)mouse:(NSEventType)type at:(NSPoint)point flags:(NSUInteger)flags clicks:(NSInteger)clicks
{
	return [NSEvent mouseEventWithType:type
	                          location:[_canvas convertPoint:point toView:nil]
	                     modifierFlags:flags
	                         timestamp:0
	                      windowNumber:[_window windowNumber]
	                           context:nil
	                       eventNumber:0
	                        clickCount:clicks
	                          pressure:1];
}

- (void)clickAt:(NSPoint)point flags:(NSUInteger)flags
{
	[_canvas mouseDown:[self mouse:NSEventTypeLeftMouseDown at:point flags:flags clicks:1]];
	[_canvas mouseUp:[self mouse:NSEventTypeLeftMouseUp at:point flags:flags clicks:1]];
}

- (void)dragFrom:(NSPoint)from to:(NSPoint)to
{
	[_canvas mouseDown:[self mouse:NSEventTypeLeftMouseDown at:from flags:0 clicks:1]];
	for (NSUInteger step = 1; step <= 4; step++) {
		NSPoint at = NSMakePoint(from.x + (to.x - from.x) * step / 4, from.y + (to.y - from.y) * step / 4);
		[_canvas mouseDragged:[self mouse:NSEventTypeLeftMouseDragged at:at flags:0 clicks:1]];
	}
	[_canvas mouseUp:[self mouse:NSEventTypeLeftMouseUp at:to flags:0 clicks:1]];
}

- (NSEvent *)key:(unichar)character flags:(NSUInteger)flags up:(BOOL)up
{
	NSString *characters = [NSString stringWithCharacters:&character length:1];
	return [NSEvent keyEventWithType:up ? NSEventTypeKeyUp : NSEventTypeKeyDown
	                        location:NSZeroPoint
	                   modifierFlags:flags
	                       timestamp:0
	                    windowNumber:[_window windowNumber]
	                         context:nil
	                      characters:characters
	     charactersIgnoringModifiers:characters
	                       isARepeat:NO
	                         keyCode:0];
}

- (NSPoint)middleOf:(NSString *)table
{
	NSRect frame = [_diagram frameOfTable:table];
	return NSMakePoint(NSMidX(frame), NSMidY(frame));
}

/* A point on no table: below them all. */
- (NSPoint)nowhere
{
	NSRect bounds = _diagram.bounds;
	return NSMakePoint(NSMinX(bounds) + 5, NSMaxY(bounds) + 30);
}

#pragma mark Selection

/* As a XIB makes it: decoded (not -initWithFrame:), then placed in its
 * scroll view before -awakeFromNib. */
- (void)testDecodedAsFromAXIB
{
	NSMutableData *archive = [NSMutableData data];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archive];
	[archiver encodeObject:[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)] forKey:@"view"];
	[archiver finishEncoding];
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
	[unarchiver setClass:[DKCanvasView class] forClassName:@"NSView"];
	DKCanvasView *canvas = [unarchiver decodeObjectForKey:@"view"];
	[unarchiver finishDecoding];
	XCTAssertTrue([canvas isKindOfClass:[DKCanvasView class]]);
	XCTAssertEqual(canvas.zoom, 1.0, @"set up when decoded");
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
	[scroll setDocumentView:canvas];
	canvas.dataSource = self;
	[canvas reloadData];
	XCTAssertTrue(isfinite(NSWidth(canvas.frame)) && NSWidth(canvas.frame) > 0, @"%@", NSStringFromRect(canvas.frame));
}

- (void)testAClickSelectsAndShiftExtends
{
	[self clickAt:[self middleOf:@"orders"] flags:0];
	XCTAssertEqualObjects(_canvas.selection, [NSSet setWithObject:@"orders"]);
	XCTAssertEqual(_selectionChanges, 1u);
	[self clickAt:[self middleOf:@"orders"] flags:0];
	XCTAssertEqual(_selectionChanges, 1u, @"selected again: no change");
	[self clickAt:[self middleOf:@"products"] flags:NSEventModifierFlagShift];
	XCTAssertEqualObjects(_canvas.selection, ([NSSet setWithObjects:@"orders", @"products", nil]));
	[self clickAt:[self middleOf:@"orders"] flags:NSEventModifierFlagCommand];
	XCTAssertEqualObjects(_canvas.selection, [NSSet setWithObject:@"products"], @"Command takes it away");
	[self clickAt:[self middleOf:@"customers"] flags:0];
	XCTAssertEqualObjects(_canvas.selection, [NSSet setWithObject:@"customers"]);
	[self clickAt:[self nowhere] flags:0];
	XCTAssertEqual([_canvas.selection count], 0u, @"a click on nothing clears it");
	XCTAssertEqual([_moves count], 0u, @"clicks move nothing");
	_canvas.selection = [NSSet setWithObject:@"orders"];
	XCTAssertEqual(_selectionChanges, 5u, @"set, not told");
}

- (void)testABandSelectsWhatItTouches
{
	NSRect orders = [_diagram frameOfTable:@"orders"], products = [_diagram frameOfTable:@"products"];
	NSRect both = NSUnionRect(orders, products);
	/* From the empty corner left of and above both, to inside them. */
	NSPoint from = NSMakePoint(NSMinX(both) - 10, NSMinY(both) - 10);
	XCTAssertNil([self canvas:_canvas itemAtPoint:from]);
	NSPoint to = NSMakePoint(NSMinX(both) + 10, NSMinY(both) + 10);
	XCTAssertTrue(NSPointInRect(to, orders) || NSPointInRect(to, products));
	NSPoint end = NSMakePoint(NSMaxX(both) - 5, NSMidY(both));
	[self dragFrom:from to:end];
	NSSet *expected = [NSSet setWithArray:[self canvas:_canvas
	                                      itemsInRect:NSMakeRect(from.x, from.y, end.x - from.x, end.y - from.y)]];
	XCTAssertTrue([expected containsObject:@"orders"] && [expected containsObject:@"products"], @"%@", expected);
	XCTAssertEqualObjects(_canvas.selection, expected);
	XCTAssertEqual(_selectionChanges, 1u, @"once, at the end");
	XCTAssertEqual([_moves count], 0u);
	/* Shift adds a band to what is selected. */
	[_canvas mouseDown:[self mouse:NSEventTypeLeftMouseDown at:[self nowhere] flags:NSEventModifierFlagShift clicks:1]];
	NSRect invoices = [_diagram frameOfTable:@"invoices"];
	[_canvas mouseDragged:[self mouse:NSEventTypeLeftMouseDragged at:NSMakePoint(NSMidX(invoices), NSMidY(invoices))
	                            flags:NSEventModifierFlagShift
	                           clicks:1]];
	[_canvas mouseUp:[self mouse:NSEventTypeLeftMouseUp at:NSMakePoint(NSMidX(invoices), NSMidY(invoices))
	                       flags:NSEventModifierFlagShift
	                      clicks:1]];
	XCTAssertTrue([_canvas.selection containsObject:@"invoices"], @"%@", _canvas.selection);
	XCTAssertTrue([_canvas.selection containsObject:@"orders"]);
}

- (void)testSelectAll
{
	[_canvas selectAll:nil];
	XCTAssertEqualObjects(_canvas.selection, [NSSet setWithArray:_diagram.tables]);
}

#pragma mark Moving

- (void)testADragCommitsOneMove
{
	NSRect before = [_diagram frameOfTable:@"orders"];
	NSPoint grab = [self middleOf:@"orders"];
	[_canvas mouseDown:[self mouse:NSEventTypeLeftMouseDown at:grab flags:0 clicks:1]];
	for (NSUInteger step = 1; step <= 5; step++) {
		[_canvas mouseDragged:[self mouse:NSEventTypeLeftMouseDragged
		                               at:NSMakePoint(grab.x + 6 * step, grab.y + 4 * step)
		                            flags:0
		                           clicks:1]];
		XCTAssertEqual([_moves count], 0u, @"nothing moves while dragging: outlines do");
	}
	[self draw];
	[_canvas mouseUp:[self mouse:NSEventTypeLeftMouseUp at:NSMakePoint(grab.x + 30, grab.y + 20) flags:0 clicks:1]];
	XCTAssertEqual([_moves count], 1u);
	XCTAssertEqualObjects([[_moves firstObject] firstObject], @[ @"orders" ]);
	XCTAssertTrue(NSEqualSizes([[[_moves firstObject] lastObject] sizeValue], NSMakeSize(30, 20)));
	NSRect after = [_diagram frameOfTable:@"orders"];
	XCTAssertEqual(NSMinX(after) - NSMinX(before), 30.0);
	XCTAssertEqualObjects(_canvas.selection, [NSSet setWithObject:@"orders"], @"pressed on: selected");
}

- (void)testTheSelectionMovesTogetherWithoutWhatIsLocked
{
	_diagram.locked = [NSSet setWithObject:@"customers"];
	_canvas.selection = [NSSet setWithObjects:@"orders", @"products", @"customers", nil];
	[self dragFrom:[self middleOf:@"products"] to:NSMakePoint([self middleOf:@"products"].x - 12.4,
	                                                         [self middleOf:@"products"].y + 7.6)];
	XCTAssertEqual([_moves count], 1u);
	XCTAssertEqualObjects([[_moves firstObject] firstObject], (@[ @"orders", @"products" ]));
	XCTAssertTrue(NSEqualSizes([[[_moves firstObject] lastObject] sizeValue], NSMakeSize(-12, 8)), @"whole points");
	/* A locked table pressed on is selected, and does not move. */
	[self dragFrom:[self middleOf:@"customers"] to:NSMakePoint([self middleOf:@"customers"].x + 50,
	                                                          [self middleOf:@"customers"].y)];
	XCTAssertEqual([_moves count], 1u);
}

- (void)testTheArrowKeysNudge
{
	_canvas.selection = [NSSet setWithObject:@"invoices"];
	[_canvas keyDown:[self key:NSRightArrowFunctionKey flags:0 up:NO]];
	[_canvas keyDown:[self key:NSUpArrowFunctionKey flags:NSEventModifierFlagShift up:NO]];
	XCTAssertEqual([_moves count], 2u);
	XCTAssertTrue(NSEqualSizes([[[_moves objectAtIndex:0] lastObject] sizeValue], NSMakeSize(1, 0)));
	XCTAssertTrue(NSEqualSizes([[[_moves objectAtIndex:1] lastObject] sizeValue], NSMakeSize(0, -10)));
}

#pragma mark Panning

- (void)testTheMiddleButtonAndSpacePan
{
	_canvas.zoom = 3;
	NSClipView *clip = [_scroll contentView];
	[clip scrollToPoint:NSMakePoint(100, 100)];
	[_scroll reflectScrolledClipView:clip];
	NSPoint origin = [clip bounds].origin;
	NSPoint at = NSMakePoint(200, 150);
	NSEvent *down = [NSEvent mouseEventWithType:NSEventTypeOtherMouseDown location:at modifierFlags:0 timestamp:0
	                               windowNumber:[_window windowNumber]
	                                    context:nil
	                                eventNumber:0
	                                 clickCount:1
	                                   pressure:1];
	NSEvent *drag = [NSEvent mouseEventWithType:NSEventTypeOtherMouseDragged location:NSMakePoint(170, 130)
	                              modifierFlags:0
	                                  timestamp:0
	                               windowNumber:[_window windowNumber]
	                                    context:nil
	                                eventNumber:0
	                                 clickCount:1
	                                   pressure:1];
	[_canvas otherMouseDown:down];
	[_canvas otherMouseDragged:drag];
	[_canvas otherMouseUp:drag];
	NSPoint panned = [clip bounds].origin;
	XCTAssertEqualWithAccuracy(fabs(panned.x - origin.x), 30, 0.5, @"%@ to %@", NSStringFromPoint(origin),
	                           NSStringFromPoint(panned));
	XCTAssertEqualWithAccuracy(fabs(panned.y - origin.y), 20, 0.5);
	/* Space held: a left drag pans too, and selects nothing. */
	[_canvas keyDown:[self key:' ' flags:0 up:NO]];
	NSPoint before = [clip bounds].origin;
	[_canvas mouseDown:[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:at modifierFlags:0 timestamp:0
	                                  windowNumber:[_window windowNumber]
	                                       context:nil
	                                   eventNumber:0
	                                    clickCount:1
	                                      pressure:1]];
	[_canvas mouseDragged:[NSEvent mouseEventWithType:NSEventTypeLeftMouseDragged location:NSMakePoint(220, 170)
	                                    modifierFlags:0
	                                        timestamp:0
	                                     windowNumber:[_window windowNumber]
	                                          context:nil
	                                      eventNumber:0
	                                       clickCount:1
	                                         pressure:1]];
	[_canvas mouseUp:[NSEvent mouseEventWithType:NSEventTypeLeftMouseUp location:NSMakePoint(220, 170) modifierFlags:0
	                                   timestamp:0
	                                windowNumber:[_window windowNumber]
	                                     context:nil
	                                 eventNumber:0
	                                  clickCount:1
	                                    pressure:1]];
	[_canvas keyUp:[self key:' ' flags:0 up:YES]];
	NSPoint after = [clip bounds].origin;
	XCTAssertEqualWithAccuracy(fabs(after.x - before.x), 20, 0.5);
	XCTAssertEqual([_canvas.selection count], 0u);
	XCTAssertEqual([_moves count], 0u);
}

#pragma mark Clicks for the delegate

- (void)testADoubleClickAndARightClickGoToTheDelegate
{
	[_canvas mouseDown:[self mouse:NSEventTypeLeftMouseDown at:[self middleOf:@"products"] flags:0 clicks:2]];
	[_canvas mouseUp:[self mouse:NSEventTypeLeftMouseUp at:[self middleOf:@"products"] flags:0 clicks:2]];
	[_canvas mouseDown:[self mouse:NSEventTypeLeftMouseDown at:[self nowhere] flags:0 clicks:2]];
	[_canvas mouseUp:[self mouse:NSEventTypeLeftMouseUp at:[self nowhere] flags:0 clicks:2]];
	XCTAssertEqualObjects(_doubleClicked, (@[ @"products", [NSNull null] ]));

	NSMenu *menu = [_canvas menuForEvent:[self mouse:NSEventTypeRightMouseDown at:[self middleOf:@"orders"] flags:0
	                                          clicks:1]];
	XCTAssertEqual(menu, _menu);
	XCTAssertEqualObjects(_menuItem, @"orders");
	XCTAssertEqualObjects(_canvas.selection, [NSSet setWithObject:@"orders"], @"selected first, as the Finder does");
}

/* A tool takes the press: the drag and the release are its, and the
 * canvas neither selects nor moves. */
- (void)testTheDelegateMayTakeAPress
{
	_tool = YES;
	NSPoint from = [self middleOf:@"orders"];
	[self dragFrom:from to:NSMakePoint(from.x + 40, from.y)];
	XCTAssertEqual([_toolEvents count], 6u, @"%@", _toolEvents);
	XCTAssertEqualObjects([_toolEvents firstObject], ([NSString stringWithFormat:@"down %g %g", from.x, from.y]));
	XCTAssertEqualObjects([_toolEvents lastObject], ([NSString stringWithFormat:@"up %g %g", from.x + 40, from.y]));
	XCTAssertEqual([_canvas.selection count], 0u);
	XCTAssertEqual([_moves count], 0u);
	_tool = NO;
	[self clickAt:from flags:0];
	XCTAssertEqualObjects(_canvas.selection, [NSSet setWithObject:@"orders"], @"the tool put away: the canvas's again");
}

- (void)testTextIsEditedInPlace
{
	NSRect frame = [_diagram frameOfTable:@"orders"];
	[_canvas editTextOfItem:@"orders" text:@"orders" inRect:NSMakeRect(NSMinX(frame), NSMinY(frame), NSWidth(frame), 20)
	                   font:nil];
	XCTAssertTrue(_canvas.isEditingText);
	NSTextField *field = nil;
	for (NSView *view in [_canvas subviews]) {
		if ([view isKindOfClass:[NSTextField class]]) {
			field = (NSTextField *)view;
		}
	}
	XCTAssertNotNil(field);
	[field setStringValue:@"purchases"];
	[_canvas endEditingText];
	XCTAssertFalse(_canvas.isEditingText);
	XCTAssertEqualObjects(_edits, (@[ @[ @"orders", @"purchases" ] ]));
	[_canvas editTextOfItem:@"orders" text:@"orders" inRect:frame font:[DKFont systemFontOfSize:11 bold:YES]];
	[_canvas cancelEditingText];
	[_canvas editTextOfItem:@"orders" text:@"orders" inRect:frame font:nil];
	[_canvas endEditingText];
	XCTAssertEqual([_edits count], 1u, @"given up, or unchanged: not told");
}

#pragma mark Zoom

- (void)testTheZoomKeepsDiagramPoints
{
	NSRect bounds = [_canvas bounds];
	NSSize frame = [_canvas frame].size;
	_canvas.zoom = 2;
	XCTAssertEqual(_canvas.zoom, 2.0);
	XCTAssertEqualWithAccuracy([_canvas frame].size.width, ceil(NSWidth([_canvas bounds]) * 2), 0.5);
	XCTAssertTrue(NSEqualPoints([_canvas bounds].origin, bounds.origin));
	XCTAssertGreaterThan([_canvas frame].size.width, frame.width);
	/* A diagram point is twice as far in the window from another. */
	NSPoint a = [_canvas convertPoint:NSMakePoint(10, 10) toView:nil];
	NSPoint b = [_canvas convertPoint:NSMakePoint(20, 10) toView:nil];
	XCTAssertEqualWithAccuracy(fabs(b.x - a.x), 20, 0.01);
	/* And a click there still finds the table at that diagram point. */
	[_canvas scrollItemToVisible:@"invoices"];
	[self clickAt:[self middleOf:@"invoices"] flags:0];
	XCTAssertEqualObjects(_canvas.selection, [NSSet setWithObject:@"invoices"]);
	[self dragFrom:[self middleOf:@"invoices"] to:NSMakePoint([self middleOf:@"invoices"].x + 10,
	                                                         [self middleOf:@"invoices"].y)];
	XCTAssertTrue(NSEqualSizes([[[_moves lastObject] lastObject] sizeValue], NSMakeSize(10, 0)), @"in diagram points");
	_canvas.zoom = 100;
	XCTAssertEqual(_canvas.zoom, 6.0);
	_canvas.zoom = 0.01;
	XCTAssertEqual(_canvas.zoom, 0.25);
	[_canvas zoomToActualSize:nil];
	XCTAssertEqual(_canvas.zoom, 1.0);
	[_canvas zoomIn:nil];
	XCTAssertEqualWithAccuracy(_canvas.zoom, 1.25, 1e-9);
	[_canvas zoomOut:nil];
	XCTAssertEqualWithAccuracy(_canvas.zoom, 1.0, 1e-9);
	[_canvas zoomToFit:nil];
	NSSize visible = [_scroll contentSize];
	NSRect drawing = NSInsetRect(_diagram.bounds, -10, -10);
	XCTAssertEqualWithAccuracy(_canvas.zoom, MIN(visible.width / NSWidth(drawing), visible.height / NSHeight(drawing)),
	                           1e-6);
}

- (void)testTheCanvasFillsItsScrollView
{
	_canvas.zoom = 0.25;
	NSSize visible = [_scroll contentSize];
	XCTAssertGreaterThanOrEqual(NSWidth([_canvas frame]), visible.width - 0.5);
	XCTAssertGreaterThanOrEqual(NSHeight([_canvas frame]), visible.height - 0.5);
#ifndef __APPLE__
	XCTAssertFalse([_scroll autohidesScrollers]);
#endif
}

#pragma mark Drawing and export

- (void)testItDrawsTheStateAndExports
{
	_canvas.selection = [NSSet setWithObject:@"orders"];
	[self draw];
	XCTAssertGreaterThan(_diagram.drawCount, 0u);
	XCTAssertFalse(_diagram.lastState.forPrinting);
	XCTAssertEqualObjects(_diagram.lastState.selection, [NSSet setWithObject:@"orders"]);

	NSData *pdf = [_canvas PDFData];
	XCTAssertGreaterThan([pdf length], 1000u);
	XCTAssertEqualObjects([[NSString alloc] initWithData:[pdf subdataWithRange:NSMakeRange(0, 4)]
	                                            encoding:NSASCIIStringEncoding],
	                      @"%PDF");
	XCTAssertTrue(_diagram.lastState.forPrinting, @"no selection in print");

	NSString *svg = [_canvas SVGString];
	XCTAssertTrue([svg rangeOfString:@"<svg"].location != NSNotFound);
	XCTAssertTrue([svg rangeOfString:@">order_lines</text>"].location != NSNotFound);
	XCTAssertTrue(_diagram.lastState.forPrinting);
	XCTAssertEqual(_canvas.zoom, 1.0, @"export leaves the zoom");

	NSPrintOperation *print = [_canvas printOperation];
	XCTAssertTrue(NSEqualSizes([[print view] frame].size, _diagram.bounds.size));
	XCTAssertTrue(NSEqualPoints([[print view] bounds].origin, _diagram.bounds.origin));
	NSData *png = [_canvas PNGDataAtScale:2.0];
	XCTAssertGreaterThan([png length], 1000u);
	[png writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"DiagramKitTests-canvas.png"] atomically:YES];
	NSBitmapImageRep *image = [NSBitmapImageRep imageRepWithData:png];
	XCTAssertEqualWithAccuracy((double)[image pixelsWide], NSWidth(_diagram.bounds) * 2, 2);
	XCTAssertEqualWithAccuracy((double)[image pixelsHigh], NSHeight(_diagram.bounds) * 2, 2);
	XCTAssertEqual(_canvas.zoom, 1.0);
}

- (void)testTheHoveredItemIsDrawn
{
	[_canvas mouseMoved:[self mouse:NSEventTypeMouseMoved at:[self middleOf:@"products"] flags:0 clicks:0]];
	XCTAssertEqualObjects(_canvas.hoveredItem, @"products");
	[self draw];
	XCTAssertEqualObjects(_diagram.lastState.hoveredItem, @"products");
	[_canvas mouseMoved:[self mouse:NSEventTypeMouseMoved at:[self nowhere] flags:0 clicks:0]];
	XCTAssertNil(_canvas.hoveredItem);
}

@end
