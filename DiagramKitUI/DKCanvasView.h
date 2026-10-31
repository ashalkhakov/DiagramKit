/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKCanvasView.h
 *
 * A diagram's view, in a scroll view: drawn by its data source, edited
 * through its delegate, everything in diagram points. It is flipped, and
 * zooms by scaling its bounds, so its own coordinates are the diagram's at
 * any zoom: a point of an event converted to it is a diagram point.
 *
 * The gestures are a drawing program's: a click selects (Shift or Command
 * adds or takes away), a drag on nothing draws a band and selects what it
 * touches, a drag of a selected item moves the selection -- dashed
 * outlines follow the pointer, and on release the delegate is told once,
 * to make it one undo step -- and the view scrolls while a drag nears its
 * edge. Space-drag and the middle button pan; the arrow keys nudge the
 * selection a point (Shift: ten); Command and the scroll wheel zoom. A
 * double-click and a right-click go to the delegate (a right-click on an
 * item not selected selects it first, as the Finder does). Delete or
 * Backspace sends -delete: up the responder chain, and other keys go up it
 * too. A client with tools (place a shape, draw an edge) takes the presses
 * it wants first (-canvas:mouseDown:atPoint:).
 *
 * Placed in a client's XIB (a custom view in a scroll view, its data
 * source and delegate outlets connected) or made in code: it sets itself
 * up either way. On GNUstep its scroll view does not autohide its
 * scrollers, which recurses in -tile around a view that resizes with it.
 */

#import <AppKit/AppKit.h>
#import <DiagramKitUI/DKAppKitSurface.h>

NS_ASSUME_NONNULL_BEGIN

@class DKCanvasView;

/// What the canvas shows: the client's diagram, by item -- the client's
/// identifiers (id<NSCopying>, compared with -isEqual:), whatever they
/// stand for.
@protocol DKCanvasDataSource <NSObject>
/// The rectangle the drawing covers, in diagram points.
- (NSRect)diagramBoundsForCanvas:(DKCanvasView *)canvas;
/// Draws what falls in @a rect onto the surface, the selection and the
/// hovered item as the state says (none, for print and export).
- (void)canvas:(DKCanvasView *)canvas
    drawInRect:(NSRect)rect
       surface:(id<DKSurface>)surface
         state:(DKDrawingState *)state;
/// The topmost item under the point; nil: nothing.
- (nullable id)canvas:(DKCanvasView *)canvas itemAtPoint:(NSPoint)point;
/// The items the rectangle touches: what a band selects.
- (NSArray *)canvas:(DKCanvasView *)canvas itemsInRect:(NSRect)rect;
/// The item's frame: what a drag outlines, and what is scrolled to.
- (NSRect)canvas:(DKCanvasView *)canvas frameOfItem:(id)item;
@optional
/// Whether a drag or the arrow keys move the item (YES unless said).
- (BOOL)canvas:(DKCanvasView *)canvas canMoveItem:(id)item;
@end

@protocol DKCanvasDelegate <NSObject>
@optional
/// The items (those of the selection that move) moved by @a delta, in
/// whole points: once for a drag, once for each nudge. The client moves
/// them, as one undo step, and reloads the canvas.
- (void)canvas:(DKCanvasView *)canvas moveItems:(NSArray *)items by:(NSSize)delta;
/// The selection changed by a gesture (not by setting it).
- (void)canvasSelectionDidChange:(DKCanvasView *)canvas;
/// A double-click on the item, or on nothing (nil).
- (void)canvas:(DKCanvasView *)canvas doubleClickedItem:(nullable id)item;
/// The menu for a right-click on the item, or on nothing (nil); nil: the
/// view's own menu.
- (nullable NSMenu *)canvas:(DKCanvasView *)canvas menuForItem:(nullable id)item;
/// The text -editTextOfItem: put up, finished (Return, or a click
/// elsewhere) and changed.
- (void)canvas:(DKCanvasView *)canvas didEditTextOfItem:(id)item text:(NSString *)text;
/// A press of the left button at @a point, before the canvas makes
/// anything of it: YES takes it -- a tool placing a shape, an edge drawn
/// out of a port -- and its drags and release are the delegate's too
/// (the canvas autoscrolls); NO leaves it to the canvas. Space-drag pans
/// first.
- (BOOL)canvas:(DKCanvasView *)canvas mouseDown:(NSEvent *)event atPoint:(NSPoint)point;
- (void)canvas:(DKCanvasView *)canvas mouseDragged:(NSEvent *)event atPoint:(NSPoint)point;
- (void)canvas:(DKCanvasView *)canvas mouseUp:(NSEvent *)event atPoint:(NSPoint)point;
@end

@interface DKCanvasView : NSView

@property (nonatomic, weak, nullable) IBOutlet id<DKCanvasDataSource> dataSource;
@property (nonatomic, weak, nullable) IBOutlet id<DKCanvasDelegate> delegate;

/// 1 is the diagram's points; clamped to 0.25 to 6. The middle of what
/// is visible stays where it is.
@property (nonatomic) double zoom;
- (IBAction)zoomIn:(nullable id)sender;
- (IBAction)zoomOut:(nullable id)sender;
/// The whole drawing in view.
- (IBAction)zoomToFit:(nullable id)sender;
/// Zoom 1.
- (IBAction)zoomToActualSize:(nullable id)sender;

/// Room beyond the drawing's right and bottom, to drag into (120 points);
/// the canvas also fills its scroll view.
@property (nonatomic) double margin;
/// What is behind the drawing; nil (the default): the text background
/// colour (dark in dark mode). Print and export are on white.
@property (nonatomic, strong, nullable) NSColor *backgroundColor;

/// The selected items. Setting it redraws, and does not tell the
/// delegate.
@property (nonatomic, copy) NSSet *selection;
/// The item under the pointer, as the data source said.
@property (nonatomic, readonly, strong, nullable) id hoveredItem;
/// The extent asked again (the drawing changed), and redrawn.
- (void)reloadData;
- (void)scrollItemToVisible:(id)item;
- (IBAction)selectAll:(nullable id)sender;

/// A text field over @a rect (diagram points), with @a text selected in
/// it, in the font (nil: the system's at 12): a name typed in place. Its
/// end is the delegate's -canvas:didEditTextOfItem:text:.
- (void)editTextOfItem:(id)item text:(NSString *)text inRect:(NSRect)rect font:(nullable DKFont *)font;
/// The edit finished (as Return does), or given up.
- (void)endEditingText;
- (void)cancelEditingText;
@property (nonatomic, readonly) BOOL isEditingText;

/// The drawing (its diagram bounds), without selection or hover, on white.
- (nullable NSData *)PDFData;
/// The same as PNG, at @a scale pixels a point. (On GNUstep, whose
/// offscreen cache of a view is empty, drawn in a window of its own, never
/// shown, and read back.)
- (nullable NSData *)PNGDataAtScale:(double)scale;
/// The drawing as SVG: the data source drawing onto a DKSVGSurface.
- (NSString *)SVGString;
/// Printing the drawing, across pages as it needs.
- (NSPrintOperation *)printOperation;
- (IBAction)print:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
