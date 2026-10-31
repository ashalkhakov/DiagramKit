/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKDrawingState.h
 *
 * What a canvas has picked out, for its data source to draw: the selected
 * items, the one under the pointer, whether this is for print or export
 * (neither of those then), the appearance and the zoom. Items are the data
 * source's own identifiers.
 */

#import <DiagramKit/DKColor.h>

NS_ASSUME_NONNULL_BEGIN

@interface DKDrawingState : NSObject
@property (nonatomic, copy) NSSet *selection;
@property (nonatomic, strong, nullable) id hoveredItem;
/// Printing or exporting: draw no selection and no hover.
@property (nonatomic) BOOL forPrinting;
/// The dark colours: YES in macOS's dark appearance; NO on GNUstep, and
/// when printing.
@property (nonatomic) BOOL dark;
/// 1 is the diagram's points; what is drawn is magnified by it.
@property (nonatomic) double zoom;
/// Whether the item is selected and the selection is to be drawn.
- (BOOL)showsSelected:(id)item;
/// Whether the item is hovered and the hover is to be drawn.
- (BOOL)showsHovered:(id)item;
@end

NS_ASSUME_NONNULL_END
