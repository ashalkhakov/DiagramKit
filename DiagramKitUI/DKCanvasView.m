/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKCanvasView.h"
#include <math.h>

/* What a gesture is doing, between mouse down and up. */
typedef NS_ENUM(NSInteger, DKGesture) {
	DKGestureNone,
	DKGestureMove,
	DKGestureBand,
	DKGesturePan,
};

static const double DKMinimumZoom = 0.25;
static const double DKMaximumZoom = 6.0;

@class DKCanvasView;

/* The drawing alone, its frame the diagram's bounds: what is printed, a
 * page at a time. */
@interface DKCanvasPrintView : NSView
@property (nonatomic, weak) DKCanvasView *canvas;
@end

@interface DKCanvasView () <NSTextFieldDelegate>
- (void)drawForPrintingInRect:(NSRect)rect;
@end

@implementation DKCanvasView
{
	BOOL _setUp;
	DKGesture _gesture;
	NSPoint _down;
	NSPoint _at;
	/* Where a pan last had the pointer, in the window: the drawing moves
	 * under it. */
	NSPoint _panFrom;
	/* Space held down: a drag pans, as in drawing programs. */
	BOOL _spaceHeld;
	/* The pan is the middle button's, not a Space-drag's. */
	BOOL _panByOtherButton;
	/* What a drag moves, and where each was when it began. */
	NSArray *_moving;
	NSArray<NSValue *> *_movingFrames;
	/* The selection a band adds to. */
	NSSet *_bandBase;
	BOOL _printing;
	BOOL _resizing;
	NSTextField *_editor;
	id _editingItem;
	NSString *_editingText;
#ifdef __APPLE__
	NSTrackingArea *_tracking;
#endif
}

- (void)setUp
{
	if (_setUp) {
		return;
	}
	_setUp = YES;
	_zoom = 1.0;
	_margin = 120;
	_selection = [NSSet set];
}

- (instancetype)initWithFrame:(NSRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		[self setUp];
	}
	return self;
}

/* From a client's XIB, which does not call -initWithFrame:. */
- (void)awakeFromNib
{
	[super awakeFromNib];
	[self setUp];
	[self reloadData];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isFlipped
{
	return YES;
}

- (BOOL)isOpaque
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
	(void)event;
	return YES;
}

- (void)setDataSource:(id<DKCanvasDataSource>)dataSource
{
	_dataSource = dataSource;
	[self reloadData];
}

#pragma mark Geometry

- (NSRect)diagramBounds
{
	if (_dataSource == nil) {
		return NSZeroRect;
	}
	return [_dataSource diagramBoundsForCanvas:self];
}

/* The frame for the drawing at the zoom: the drawing and the margin, and
 * at least what the scroll view shows, so a small diagram can grow
 * anywhere in it. The bounds are the diagram's points. */
- (void)resize
{
	if (_resizing) {
		return;
	}
	_resizing = YES;
	NSRect drawing = [self diagramBounds];
	NSRect area = NSMakeRect(0, 0, 1, 1);
	if (!NSIsEmptyRect(drawing)) {
		area = NSUnionRect(drawing, area);
	}
	area.size.width += _margin;
	area.size.height += _margin;
	NSScrollView *scroll = [self enclosingScrollView];
	if (scroll != nil) {
		NSSize visible = [scroll contentSize];
		area.size.width = MAX(area.size.width, visible.width / _zoom);
		area.size.height = MAX(area.size.height, visible.height / _zoom);
	}
	[self setFrameSize:NSMakeSize(ceil(NSWidth(area) * _zoom), ceil(NSHeight(area) * _zoom))];
	[self setBoundsOrigin:area.origin];
	[self setBoundsSize:area.size];
	[self setNeedsDisplay:YES];
	_resizing = NO;
}

- (void)reloadData
{
	[self resize];
	[self setNeedsDisplay:YES];
}

/* The zoom changed, the point staying where it is in what is visible. */
- (void)zoomTo:(double)zoom keeping:(NSPoint)point
{
	if (isnan(zoom)) {
		return;
	}
	zoom = MIN(MAX(zoom, DKMinimumZoom), DKMaximumZoom);
	NSRect visible = [self visibleRect];
	BOOL shown = !NSIsEmptyRect(visible);
	double fx = shown ? (point.x - NSMinX(visible)) / NSWidth(visible) : 0;
	double fy = shown ? (point.y - NSMinY(visible)) / NSHeight(visible) : 0;
	_zoom = zoom;
	[self resize];
	NSRect now = [self visibleRect];
	if (shown && !NSIsEmptyRect(now)) {
		[self scrollPoint:NSMakePoint(point.x - fx * NSWidth(now), point.y - fy * NSHeight(now))];
	}
}

- (void)setZoom:(double)zoom
{
	NSRect visible = [self visibleRect];
	[self zoomTo:zoom keeping:NSMakePoint(NSMidX(visible), NSMidY(visible))];
}

- (IBAction)zoomIn:(id)sender
{
	(void)sender;
	self.zoom = _zoom * 1.25;
}

- (IBAction)zoomOut:(id)sender
{
	(void)sender;
	self.zoom = _zoom / 1.25;
}

- (IBAction)zoomToActualSize:(id)sender
{
	(void)sender;
	self.zoom = 1.0;
}

- (IBAction)zoomToFit:(id)sender
{
	(void)sender;
	NSRect drawing = NSInsetRect([self diagramBounds], -10, -10);
	NSScrollView *scroll = [self enclosingScrollView];
	NSSize visible = scroll != nil ? [scroll contentSize] : [self frame].size;
	if (NSWidth(drawing) > 0 && NSHeight(drawing) > 0 && visible.width > 0 && visible.height > 0) {
		_zoom = MIN(MAX(MIN(visible.width / NSWidth(drawing), visible.height / NSHeight(drawing)), DKMinimumZoom),
		            DKMaximumZoom);
		[self resize];
		[self scrollPoint:drawing.origin];
	}
}

- (void)setMargin:(double)margin
{
	_margin = MAX(0.0, margin);
	[self resize];
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
	_backgroundColor = backgroundColor;
	[self setNeedsDisplay:YES];
}

- (NSPoint)pointOf:(NSEvent *)event
{
	return [self convertPoint:[event locationInWindow] fromView:nil];
}

#pragma mark The scroll view

- (void)viewDidMoveToSuperview
{
	[super viewDidMoveToSuperview];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:NSViewFrameDidChangeNotification object:nil];
	NSScrollView *scroll = [self enclosingScrollView];
	if (scroll == nil) {
		return;
	}
#ifndef __APPLE__
	/* gnustep-gui's -tile recurses without end when the scrollers hide
	 * around a view that resizes with its scroll view. */
	[scroll setAutohidesScrollers:NO];
#endif
	NSClipView *clip = [scroll contentView];
	[clip setPostsFrameChangedNotifications:YES];
	[center addObserver:self selector:@selector(clipFrameDidChange:) name:NSViewFrameDidChangeNotification object:clip];
	[self resize];
}

/* The scroll view resized: the canvas fills it still. */
- (void)clipFrameDidChange:(NSNotification *)notification
{
	(void)notification;
	[self resize];
}

#pragma mark Selection

- (void)setSelection:(NSSet *)selection
{
	_selection = [selection copy] ?: [NSSet set];
	[self setNeedsDisplay:YES];
}

/* The selection changed by a gesture: the delegate told, if it did. */
- (void)select:(NSSet *)selection
{
	if ([selection isEqualToSet:_selection]) {
		return;
	}
	self.selection = selection;
	if ([_delegate respondsToSelector:@selector(canvasSelectionDidChange:)]) {
		[_delegate canvasSelectionDidChange:self];
	}
}

- (BOOL)canMove:(id)item
{
	if ([_dataSource respondsToSelector:@selector(canvas:canMoveItem:)]) {
		return [_dataSource canvas:self canMoveItem:item];
	}
	return YES;
}

/* The selected items that move, in a stable order. */
- (NSArray *)movableSelection
{
	NSMutableArray *items = [NSMutableArray array];
	for (id item in _selection) {
		if ([self canMove:item]) {
			[items addObject:item];
		}
	}
	return items;
}

- (void)scrollItemToVisible:(id)item
{
	if (_dataSource == nil || item == nil) {
		return;
	}
	NSRect frame = [_dataSource canvas:self frameOfItem:item];
	if (!NSIsEmptyRect(frame)) {
		[self scrollRectToVisible:NSInsetRect(frame, -20, -20)];
	}
}

- (IBAction)selectAll:(id)sender
{
	(void)sender;
	NSRect everything = NSInsetRect([self diagramBounds], -1, -1);
	NSArray *items = _dataSource != nil ? [_dataSource canvas:self itemsInRect:everything] : @[];
	[self select:[NSSet setWithArray:items]];
}

#pragma mark Drawing

- (BOOL)isDark
{
#ifdef __APPLE__
	NSAppearanceName name =
		[[self effectiveAppearance] bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
	return [name isEqualToString:NSAppearanceNameDarkAqua];
#else
	return NO;
#endif
}

- (DKDrawingState *)stateForPrinting:(BOOL)printing
{
	DKDrawingState *state = [[DKDrawingState alloc] init];
	state.selection = _selection;
	state.hoveredItem = _hoveredItem;
	state.forPrinting = printing;
	state.dark = !printing && [self isDark];
	state.zoom = printing ? 1.0 : _zoom;
	return state;
}

- (void)drawRect:(NSRect)dirty
{
	BOOL printing = _printing;
	[(printing ? [NSColor whiteColor] : (_backgroundColor ?: [NSColor textBackgroundColor])) setFill];
	NSRectFill(dirty);
	if (_dataSource == nil) {
		return;
	}
	[_dataSource canvas:self drawInRect:dirty surface:[DKAppKitSurface surface] state:[self stateForPrinting:printing]];
	if (!printing) {
		[self drawGesture];
	}
}

- (void)drawForPrintingInRect:(NSRect)rect
{
	[[NSColor whiteColor] setFill];
	NSRectFill(rect);
	if (_dataSource != nil) {
		[_dataSource canvas:self drawInRect:rect surface:[DKAppKitSurface surface] state:[self stateForPrinting:YES]];
	}
}

- (NSRect)band
{
	return NSMakeRect(MIN(_down.x, _at.x), MIN(_down.y, _at.y), fabs(_at.x - _down.x), fabs(_at.y - _down.y));
}

/* What is dragged, outlined where it would go; the band, tinted. */
- (void)drawGesture
{
	NSColor *color = DKNSColor(DKColorSelection());
	double hairline = 1.0 / MAX(_zoom, 0.01);
	switch (_gesture) {
	case DKGestureMove: {
		NSSize delta = NSMakeSize(_at.x - _down.x, _at.y - _down.y);
		if (fabs(delta.width) < 1 && fabs(delta.height) < 1) {
			break;
		}
		for (NSValue *frame in _movingFrames) {
			NSBezierPath *path = [NSBezierPath bezierPathWithRect:NSOffsetRect([frame rectValue], delta.width, delta.height)];
			CGFloat pattern[2] = { 3.0 * hairline, 2.0 * hairline };
			[path setLineDash:pattern count:2 phase:0];
			[path setLineWidth:hairline];
			[color setStroke];
			[path stroke];
		}
		break;
	}
	case DKGestureBand: {
		NSRect band = [self band];
		[[color colorWithAlphaComponent:0.12] setFill];
		NSRectFillUsingOperation(band, NSCompositingOperationSourceOver);
		NSBezierPath *path = [NSBezierPath bezierPathWithRect:band];
		[path setLineWidth:hairline];
		[color setStroke];
		[path stroke];
		break;
	}
	case DKGesturePan:
	case DKGestureNone:
		break;
	}
}

#pragma mark Mouse

- (void)mouseDown:(NSEvent *)event
{
	[[self window] makeFirstResponder:self];
	[self endEditingText];
	NSPoint point = [self pointOf:event];
	_down = point;
	_at = point;
	if (_gesture == DKGesturePan) {
		/* A pan with the middle button: the left one waits for it. */
		return;
	}
	_panFrom = [event locationInWindow];
	if (_spaceHeld) {
		[self beginPan];
		return;
	}
	id item = _dataSource != nil ? [_dataSource canvas:self itemAtPoint:point] : nil;
	if ([event clickCount] == 2) {
		if ([_delegate respondsToSelector:@selector(canvas:doubleClickedItem:)]) {
			[_delegate canvas:self doubleClickedItem:item];
		}
		return;
	}
	BOOL extend = ([event modifierFlags] & (NSEventModifierFlagShift | NSEventModifierFlagCommand)) != 0;
	if (item == nil) {
		if (!extend) {
			[self select:[NSSet set]];
		}
		_bandBase = _selection;
		_gesture = DKGestureBand;
		[self setNeedsDisplay:YES];
		return;
	}
	if (extend) {
		NSMutableSet *selection = [_selection mutableCopy];
		if ([selection containsObject:item]) {
			[selection removeObject:item];
		} else {
			[selection addObject:item];
		}
		[self select:selection];
	} else if (![_selection containsObject:item]) {
		[self select:[NSSet setWithObject:item]];
	}
	if (![_selection containsObject:item] || ![self canMove:item]) {
		return;
	}
	/* What is selected is dragged together. */
	_moving = [self movableSelection];
	NSMutableArray *frames = [NSMutableArray array];
	for (id moving in _moving) {
		[frames addObject:[NSValue valueWithRect:[_dataSource canvas:self frameOfItem:moving]]];
	}
	_movingFrames = frames;
	_gesture = DKGestureMove;
}

- (void)mouseDragged:(NSEvent *)event
{
	if (_gesture == DKGesturePan) {
		if (!_panByOtherButton) {
			[self panTo:[event locationInWindow]];
		}
		return;
	}
	if (_gesture == DKGestureNone) {
		return;
	}
	_at = [self pointOf:event];
	[self autoscroll:event];
	[self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event
{
	if (_gesture == DKGesturePan && _panByOtherButton) {
		/* The middle button's pan goes on. */
		return;
	}
	DKGesture gesture = _gesture;
	_gesture = DKGestureNone;
	if (gesture != DKGestureNone && gesture != DKGesturePan) {
		_at = [self pointOf:event];
	}
	switch (gesture) {
	case DKGestureMove: {
		NSSize delta = NSMakeSize(round(_at.x - _down.x), round(_at.y - _down.y));
		NSArray *moving = _moving;
		if ((fabs(delta.width) >= 1 || fabs(delta.height) >= 1) && [moving count] > 0
		    && [_delegate respondsToSelector:@selector(canvas:moveItems:by:)]) {
			[_delegate canvas:self moveItems:moving by:delta];
		}
		break;
	}
	case DKGestureBand: {
		NSRect band = [self band];
		if (NSWidth(band) >= 2 || NSHeight(band) >= 2) {
			NSMutableSet *selection = [_bandBase mutableCopy] ?: [NSMutableSet set];
			if (_dataSource != nil) {
				[selection addObjectsFromArray:[_dataSource canvas:self itemsInRect:band]];
			}
			[self select:selection];
		}
		break;
	}
	case DKGesturePan:
		[self endPan];
		break;
	case DKGestureNone:
		break;
	}
	_moving = nil;
	_movingFrames = nil;
	_bandBase = nil;
	[self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)event
{
	if (_dataSource == nil || _gesture != DKGestureNone) {
		return;
	}
	NSPoint point = [self pointOf:event];
	id item = NSPointInRect(point, [self bounds]) ? [_dataSource canvas:self itemAtPoint:point] : nil;
	if (item != _hoveredItem && ![item isEqual:_hoveredItem]) {
		_hoveredItem = item;
		[self setNeedsDisplay:YES];
	}
}

- (void)mouseExited:(NSEvent *)event
{
	(void)event;
	if (_hoveredItem != nil) {
		_hoveredItem = nil;
		[self setNeedsDisplay:YES];
	}
}

#ifdef __APPLE__
- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	if (_tracking != nil) {
		[self removeTrackingArea:_tracking];
	}
	_tracking = [[NSTrackingArea alloc]
		initWithRect:NSZeroRect
		     options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
		             | NSTrackingInVisibleRect
		       owner:self
		    userInfo:nil];
	[self addTrackingArea:_tracking];
}
#endif

/* A pan: with Space held down, or with the middle button; the scroll
 * wheel and the trackpad pan as any scroll view does. */
- (void)beginPan
{
	_gesture = DKGesturePan;
	[[NSCursor closedHandCursor] push];
}

- (void)endPan
{
	_gesture = DKGestureNone;
	_panByOtherButton = NO;
	[NSCursor pop];
}

- (void)otherMouseDown:(NSEvent *)event
{
	if (_gesture != DKGestureNone) {
		/* Another gesture has the canvas: the middle button waits. */
		return;
	}
	_panFrom = [event locationInWindow];
	_panByOtherButton = YES;
	[self beginPan];
}

- (void)otherMouseDragged:(NSEvent *)event
{
	if (_gesture == DKGesturePan && _panByOtherButton) {
		[self panTo:[event locationInWindow]];
	}
}

- (void)otherMouseUp:(NSEvent *)event
{
	(void)event;
	if (_gesture == DKGesturePan && _panByOtherButton) {
		[self endPan];
	}
}

/* The drawing scrolled so that what was under the pointer stays under it,
 * as far as there is drawing to show. */
- (void)panTo:(NSPoint)location
{
	NSScrollView *scroll = [self enclosingScrollView];
	NSClipView *clip = [scroll contentView];
	if (clip == nil) {
		return;
	}
	NSPoint from = [clip convertPoint:_panFrom fromView:nil];
	NSPoint to = [clip convertPoint:location fromView:nil];
	_panFrom = location;
	NSRect visible = [clip bounds];
	NSRect document = [[clip documentView] frame];
	NSPoint origin = NSMakePoint(NSMinX(visible) - (to.x - from.x), NSMinY(visible) - (to.y - from.y));
	origin.x = MAX(NSMinX(document), MIN(origin.x, NSMaxX(document) - NSWidth(visible)));
	origin.y = MAX(NSMinY(document), MIN(origin.y, NSMaxY(document) - NSHeight(visible)));
	[clip scrollToPoint:origin];
	[scroll reflectScrolledClipView:clip];
}

- (void)scrollWheel:(NSEvent *)event
{
	if ([event modifierFlags] & NSEventModifierFlagCommand) {
		double delta = [event deltaY];
		if (delta != 0) {
			[self zoomTo:_zoom * (delta > 0 ? 1.1 : 1 / 1.1) keeping:[self pointOf:event]];
		}
		return;
	}
	[super scrollWheel:event];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
	NSPoint point = [self pointOf:event];
	id item = _dataSource != nil ? [_dataSource canvas:self itemAtPoint:point] : nil;
	if (item != nil && ![_selection containsObject:item]) {
		[self select:[NSSet setWithObject:item]];
	}
	NSMenu *menu = nil;
	if ([_delegate respondsToSelector:@selector(canvas:menuForItem:)]) {
		menu = [_delegate canvas:self menuForItem:item];
	}
	return menu ?: [super menuForEvent:event];
}

#pragma mark Keys

- (void)keyDown:(NSEvent *)event
{
	NSString *characters = [event charactersIgnoringModifiers];
	unichar key = [characters length] > 0 ? [characters characterAtIndex:0] : 0;
	double step = ([event modifierFlags] & NSEventModifierFlagShift) ? 10 : 1;
	switch (key) {
	case ' ':
		if (!_spaceHeld) {
			_spaceHeld = YES;
			[[NSCursor openHandCursor] set];
		}
		return;
	case NSLeftArrowFunctionKey:
		[self nudge:NSMakeSize(-step, 0)];
		return;
	case NSRightArrowFunctionKey:
		[self nudge:NSMakeSize(step, 0)];
		return;
	case NSUpArrowFunctionKey:
		[self nudge:NSMakeSize(0, -step)];
		return;
	case NSDownArrowFunctionKey:
		[self nudge:NSMakeSize(0, step)];
		return;
	case NSDeleteCharacter:
	case NSBackspaceCharacter:
	case NSDeleteFunctionKey:
		[NSApp sendAction:@selector(delete:) to:nil from:self];
		return;
	default:
		break;
	}
	[super keyDown:event];
}

- (void)keyUp:(NSEvent *)event
{
	if ([[event charactersIgnoringModifiers] isEqualToString:@" "]) {
		[self forgetSpace];
		return;
	}
	[super keyUp:event];
}

/* Space let go elsewhere: no pan is armed. */
- (void)forgetSpace
{
	if (_spaceHeld) {
		_spaceHeld = NO;
		[[NSCursor arrowCursor] set];
	}
}

- (BOOL)resignFirstResponder
{
	[self forgetSpace];
	return [super resignFirstResponder];
}

/* Another window made key keeps this one's first responder, but takes
 * the keys: a Space let go there never reaches the canvas. */
- (void)viewWillMoveToWindow:(NSWindow *)window
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	if ([self window] != nil) {
		[center removeObserver:self name:NSWindowDidResignKeyNotification object:[self window]];
	}
	if (window != nil) {
		[center addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification
		             object:window];
	}
	[super viewWillMoveToWindow:window];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
#ifndef __APPLE__
	/* No tracking areas in gnustep-gui: the window's moves, then. */
	[[self window] setAcceptsMouseMovedEvents:YES];
#endif
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	(void)notification;
	[self forgetSpace];
}

- (void)nudge:(NSSize)delta
{
	NSArray *items = [self movableSelection];
	if ([items count] > 0 && [_delegate respondsToSelector:@selector(canvas:moveItems:by:)]) {
		[_delegate canvas:self moveItems:items by:delta];
	}
}

#pragma mark Text in place

- (BOOL)isEditingText
{
	return _editor != nil;
}

- (void)editTextOfItem:(id)item text:(NSString *)text inRect:(NSRect)rect font:(DKFont *)font
{
	[self endEditingText];
	NSFont *nsFont = DKNSFont(font ?: [DKFont systemFontOfSize:12 bold:NO]);
	NSRect frame = rect;
	frame.size.height = MAX(NSHeight(frame), ceil([nsFont pointSize] * 1.6));
	frame.size.width = MAX(NSWidth(frame), 40);
	NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
	[field setStringValue:text ?: @""];
	[field setFont:nsFont];
	[field setAlignment:NSTextAlignmentCenter];
	[field setTarget:self];
	[field setAction:@selector(editorDone:)];
	[field setDelegate:self];
	_editor = field;
	_editingItem = item;
	_editingText = [text copy] ?: @"";
	[self addSubview:field];
	[self scrollRectToVisible:NSInsetRect(frame, -20, -20)];
	[[self window] makeFirstResponder:field];
	[field selectText:nil];
}

- (void)editorDone:(id)sender
{
	(void)sender;
	[self endEditingText];
}

- (void)finishEditing:(BOOL)commit
{
	if (_editor == nil) {
		return;
	}
	NSTextField *field = _editor;
	NSString *text = [field stringValue];
	id item = _editingItem;
	NSString *before = _editingText;
	_editor = nil;
	_editingItem = nil;
	_editingText = nil;
	[field setDelegate:nil];
	[field setTarget:nil];
	[field removeFromSuperview];
	[[self window] makeFirstResponder:self];
	if (commit && ![text isEqualToString:before] && [_delegate respondsToSelector:@selector(canvas:didEditTextOfItem:text:)]) {
		[_delegate canvas:self didEditTextOfItem:item text:text];
	}
}

- (void)endEditingText
{
	[self finishEditing:YES];
}

- (void)cancelEditingText
{
	[self finishEditing:NO];
}

/* Escape in the field gives the edit up. */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)selector
{
	(void)control;
	(void)textView;
	if (selector == @selector(cancelOperation:)) {
		[self cancelEditingText];
		return YES;
	}
	return NO;
}

#pragma mark Export and print

- (NSData *)PDFData
{
	NSRect area = [self diagramBounds];
	if (NSIsEmptyRect(area)) {
		return nil;
	}
	[self resize];
	_printing = YES;
	NSData *data = [self dataWithPDFInsideRect:area];
	_printing = NO;
	[self setNeedsDisplay:YES];
	return data;
}

/* The drawing alone, @a scale pixels a point: a view of its own, the
 * diagram's bounds its bounds. */
- (DKCanvasPrintView *)drawingViewAtScale:(double)scale
{
	NSRect area = [self diagramBounds];
	if (NSIsEmptyRect(area)) {
		area = NSMakeRect(0, 0, 1, 1);
	}
	NSRect frame = NSMakeRect(0, 0, ceil(NSWidth(area) * scale), ceil(NSHeight(area) * scale));
	DKCanvasPrintView *view = [[DKCanvasPrintView alloc] initWithFrame:frame];
	[view setBoundsOrigin:area.origin];
	[view setBoundsSize:area.size];
	view.canvas = self;
	return view;
}

- (NSData *)PNGDataAtScale:(double)scale
{
	if (NSIsEmptyRect([self diagramBounds]) || scale <= 0) {
		return nil;
	}
	DKCanvasPrintView *view = [self drawingViewAtScale:scale];
	NSRect area = [view bounds];
	NSBitmapImageRep *bitmap = nil;
#if defined(__APPLE__)
	bitmap = [view bitmapImageRepForCachingDisplayInRect:area];
	[view cacheDisplayInRect:area toBitmapImageRep:bitmap];
#else
	/* gnustep-gui's offscreen cache of a view is empty: the view drawn in
	 * a window of its own, never shown, and the window read back. */
	NSWindow *window = [[NSWindow alloc] initWithContentRect:[view frame]
	                                               styleMask:NSWindowStyleMaskBorderless
	                                                 backing:NSBackingStoreBuffered
	                                                   defer:NO];
	[window setReleasedWhenClosed:NO];
	[window setContentView:view];
	[view setBoundsOrigin:area.origin];
	[view setBoundsSize:area.size];
	[view display];
	[view lockFocus];
	bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:area];
	[view unlockFocus];
	[window close];
#endif
	return [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

- (NSString *)SVGString
{
	NSRect area = [self diagramBounds];
	DKSVGSurface *surface = [[DKSVGSurface alloc] initWithBounds:area];
	surface.background = DKColorWhite();
	if (_dataSource != nil) {
		[_dataSource canvas:self drawInRect:area surface:surface state:[self stateForPrinting:YES]];
	}
	return [surface SVGString];
}

- (NSPrintOperation *)printOperation
{
	NSPrintInfo *info = [[NSPrintInfo sharedPrintInfo] copy];
	[info setHorizontallyCentered:YES];
	[info setVerticallyCentered:NO];
	return [NSPrintOperation printOperationWithView:[self drawingViewAtScale:1.0] printInfo:info];
}

- (IBAction)print:(id)sender
{
	(void)sender;
	NSPrintOperation *operation = [self printOperation];
	if ([self window] != nil) {
		[operation runOperationModalForWindow:[self window] delegate:nil didRunSelector:NULL contextInfo:NULL];
	} else {
		[operation runOperation];
	}
}

@end

@implementation DKCanvasPrintView

- (BOOL)isFlipped
{
	return YES;
}

- (void)drawRect:(NSRect)dirty
{
	[self.canvas drawForPrintingInRect:dirty];
}

@end
