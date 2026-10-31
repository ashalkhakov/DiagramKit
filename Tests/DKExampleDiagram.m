/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKExampleDiagram.h"

static const double DKRowHeight = 15;
static const double DKHeaderHeight = 22;
static const double DKTableWidth = 150;

@implementation DKExampleDiagram
{
	NSMutableArray<NSString *> *_tables;
	NSMutableDictionary<NSString *, NSArray<NSString *> *> *_columns;
	NSMutableDictionary<NSString *, NSValue *> *_frames;
	/* [child, parent, child's end, parent's end] */
	NSArray<NSArray *> *_references;
}

+ (instancetype)shop
{
	DKExampleDiagram *diagram = [[self alloc] init];
	[diagram addTable:@"customers" columns:@[ @"id  integer", @"name  text", @"email  text" ]];
	[diagram addTable:@"categories" columns:@[ @"id  integer", @"title  text" ]];
	[diagram addTable:@"orders" columns:@[ @"id  integer", @"customer_id  integer", @"placed_at  timestamp" ]];
	[diagram addTable:@"products" columns:@[ @"id  integer", @"category_id  integer", @"name  text", @"price  numeric" ]];
	[diagram addTable:@"order_lines" columns:@[ @"order_id  integer", @"product_id  integer", @"quantity  integer" ]];
	[diagram addTable:@"invoices" columns:@[ @"order_id  integer", @"total  numeric" ]];
	diagram->_references = @[
		@[ @"orders", @"customers", @(DKEdgeEndCrowFootZeroOrMany), @(DKEdgeEndCrowFootOne) ],
		@[ @"products", @"categories", @(DKEdgeEndCrowFootZeroOrMany), @(DKEdgeEndCrowFootZeroOrOne) ],
		@[ @"order_lines", @"orders", @(DKEdgeEndCrowFootOneOrMany), @(DKEdgeEndCrowFootOne) ],
		@[ @"order_lines", @"products", @(DKEdgeEndCrowFootMany), @(DKEdgeEndCrowFootOne) ],
		@[ @"invoices", @"orders", @(DKEdgeEndCrowFootZeroOrOne), @(DKEdgeEndCrowFootOne) ],
	];
	DKLayeredLayout *layout = [[DKLayeredLayout alloc] init];
	layout.direction = DKLayoutTopToBottom;
	layout.layerSpacing = 50;
	for (NSString *table in diagram->_tables) {
		[layout addNode:table size:[diagram sizeOfTable:table]];
	}
	for (NSArray *reference in diagram->_references) {
		[layout addEdgeFrom:[reference objectAtIndex:1] to:[reference objectAtIndex:0]];
	}
	NSDictionary *frames = [layout layout];
	for (NSString *table in frames) {
		[diagram->_frames setObject:[NSValue valueWithRect:NSOffsetRect([[frames objectForKey:table] rectValue], 20, 20)]
		                     forKey:table];
	}
	return diagram;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_tables = [NSMutableArray array];
		_columns = [NSMutableDictionary dictionary];
		_frames = [NSMutableDictionary dictionary];
		_references = @[];
		_locked = [NSSet set];
	}
	return self;
}

- (void)addTable:(NSString *)table columns:(NSArray *)columns
{
	[_tables addObject:table];
	[_columns setObject:columns forKey:table];
}

- (NSSize)sizeOfTable:(NSString *)table
{
	return NSMakeSize(DKTableWidth, DKHeaderHeight + DKRowHeight * [[_columns objectForKey:table] count] + 6);
}

- (NSArray<NSString *> *)tables
{
	return [_tables copy];
}

- (NSRect)frameOfTable:(NSString *)table
{
	NSValue *frame = [_frames objectForKey:table];
	return frame != nil ? [frame rectValue] : NSZeroRect;
}

- (void)moveTable:(NSString *)table by:(NSSize)delta
{
	[_frames setObject:[NSValue valueWithRect:NSOffsetRect([self frameOfTable:table], delta.width, delta.height)]
	            forKey:table];
}

- (NSRect)bounds
{
	NSRect bounds = NSZeroRect;
	for (NSString *table in _tables) {
		bounds = NSIsEmptyRect(bounds) ? [self frameOfTable:table] : NSUnionRect(bounds, [self frameOfTable:table]);
	}
	return NSInsetRect(bounds, -20, -20);
}

- (void)drawOn:(id<DKSurface>)surface state:(DKDrawingState *)state
{
	DKColor ink = state.dark ? DKColorMake(0.88, 0.88, 0.88, 1) : DKColorMake(0.15, 0.15, 0.2, 1);
	DKColor paper = state.dark ? DKColorMake(0.16, 0.16, 0.18, 1) : DKColorWhite();
	DKColor header = state.dark ? DKColorMake(0.20, 0.27, 0.40, 1) : DKColorMake(0.85, 0.90, 0.98, 1);
	/* The foreign keys first, under the tables. */
	for (NSArray *reference in _references) {
		NSString *child = [reference objectAtIndex:0], *parent = [reference objectAtIndex:1];
		NSMutableArray *others = [NSMutableArray array];
		for (NSString *table in _tables) {
			if (![table isEqualToString:child] && ![table isEqualToString:parent]) {
				[others addObject:[NSValue valueWithRect:[self frameOfTable:table]]];
			}
		}
		NSArray *route = [DKOrthogonalRouter routeFrom:[self frameOfTable:child] to:[self frameOfTable:parent]
		                                      avoiding:others];
		DKDrawRoute(surface, route, ink, 1, NO, (DKEdgeEnd)[[reference objectAtIndex:2] integerValue],
		            (DKEdgeEnd)[[reference objectAtIndex:3] integerValue]);
	}
	DKFont *title = [DKFont systemFontOfSize:11 bold:YES];
	DKFont *column = [DKFont systemFontOfSize:9.5 bold:NO];
	for (NSString *table in _tables) {
		NSRect frame = [self frameOfTable:table];
		DKPath *outline = [DKPath pathWithRoundedRect:frame radius:5];
		[surface fillPath:outline color:paper];
		DKPath *top = [DKPath path];
		[top moveTo:NSMakePoint(NSMinX(frame), NSMinY(frame) + DKHeaderHeight)];
		[top lineTo:NSMakePoint(NSMinX(frame), NSMinY(frame) + 5)];
		[top curveTo:NSMakePoint(NSMinX(frame) + 5, NSMinY(frame)) control1:NSMakePoint(NSMinX(frame), NSMinY(frame) + 2.2)
		    control2:NSMakePoint(NSMinX(frame) + 2.2, NSMinY(frame))];
		[top lineTo:NSMakePoint(NSMaxX(frame) - 5, NSMinY(frame))];
		[top curveTo:NSMakePoint(NSMaxX(frame), NSMinY(frame) + 5) control1:NSMakePoint(NSMaxX(frame) - 2.2, NSMinY(frame))
		    control2:NSMakePoint(NSMaxX(frame), NSMinY(frame) + 2.2)];
		[top lineTo:NSMakePoint(NSMaxX(frame), NSMinY(frame) + DKHeaderHeight)];
		[top close];
		[surface fillPath:top color:[state showsHovered:table] ? DKColorWithAlpha(DKColorSelection(), 0.3) : header];
		[surface strokePath:[DKPath pathWithLineFrom:NSMakePoint(NSMinX(frame), NSMinY(frame) + DKHeaderHeight)
		                                          to:NSMakePoint(NSMaxX(frame), NSMinY(frame) + DKHeaderHeight)]
		              color:ink
		              width:0.75
		             dashed:NO];
		BOOL selected = [state showsSelected:table];
		[surface strokePath:outline color:selected ? DKColorSelection() : ink width:selected ? 2 : 1 dashed:NO];
		[surface drawText:table at:NSMakePoint(NSMidX(frame), NSMinY(frame) + 4) font:title color:ink centered:YES];
		double y = NSMinY(frame) + DKHeaderHeight + 3;
		for (NSString *text in [_columns objectForKey:table]) {
			[surface drawText:text at:NSMakePoint(NSMinX(frame) + 8, y) font:column color:ink centered:NO];
			y += DKRowHeight;
		}
	}
}

@end
