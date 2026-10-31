/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKSVGSurface.h
 *
 * A surface that writes SVG: what is drawn on it, as a standalone SVG
 * document of the size (or showing the rectangle) it was made with.
 * Rectangles, rounded rectangles and ovals are <rect> and <ellipse>, other
 * paths <path>; text is <text>, its baseline an em below the point.
 *
 * Foundation has no fonts to measure with, so text widths are estimated
 * from the font's size (a Tahoma-like face's advances); text that is
 * centred is centred by the SVG renderer (text-anchor), so only left-set
 * text depends on the estimate.
 */

#import <DiagramKit/DKSurface.h>

NS_ASSUME_NONNULL_BEGIN

@interface DKSVGSurface : NSObject <DKSurface>

/// A document @a size points wide and high, from (0, 0).
- (instancetype)initWithSize:(NSSize)size;
/// A document showing @a bounds of the diagram: its viewBox.
- (instancetype)initWithBounds:(NSRect)bounds;

/// The document's <title>; nil: none.
@property (nonatomic, copy, nullable) NSString *title;
/// The paper under the drawing; transparent (alpha 0, the default): none.
@property (nonatomic) DKColor background;

/// The drawing so far, as an SVG document.
- (NSString *)SVGString;

@end

NS_ASSUME_NONNULL_END
