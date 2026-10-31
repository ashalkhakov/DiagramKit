/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKSurface.h
 *
 * What a diagram is drawn onto: a view (DiagramKitUI's DKAppKitSurface),
 * an SVG document (DKSVGSurface), a test's recording. A client's painter
 * knows its notation and geometry and draws through this alone, so the
 * same painter draws everywhere. Everything is in diagram points, flipped:
 * y grows downward.
 */

#import <DiagramKit/DKPath.h>
#import <DiagramKit/DKFont.h>

NS_ASSUME_NONNULL_BEGIN

/// How a line of text is turned: a quarter anticlockwise reads bottom to
/// top (a BPMN lane's name, down its left side), clockwise top to bottom.
typedef NS_ENUM(NSInteger, DKTextRotation) {
	DKTextRotationNone,
	DKTextRotationQuarterAnticlockwise,
	DKTextRotationQuarterClockwise,
};

/// How a path is stroked: BPMN tells three apart -- a sequence flow solid,
/// a non-interrupting event's outline dashed, an association dotted.
typedef NS_ENUM(NSInteger, DKStrokeStyle) {
	DKStrokeSolid,
	DKStrokeDashed,
	DKStrokeDotted,
};

@protocol DKSurface <NSObject>

/// The text's width and line height in the font, as this surface sets it.
- (NSSize)sizeOfText:(NSString *)text font:(DKFont *)font;
/// The text wrapped at words to the width, as -drawText:inRect:font:color:
/// sets it: its widest line, and its lines' height (to centre it in a box).
- (NSSize)sizeOfText:(NSString *)text font:(DKFont *)font wrappedToWidth:(double)width;
/// Dashed or dotted: in DKStrokePattern(style, width)'s dashes and gaps.
- (void)strokePath:(DKPath *)path color:(DKColor)color width:(double)width style:(DKStrokeStyle)style;
- (void)fillPath:(DKPath *)path color:(DKColor)color;
/// One line of text from its top left corner, or, centred, from the
/// middle of its top edge.
- (void)drawText:(NSString *)text at:(NSPoint)point font:(DKFont *)font color:(DKColor)color centered:(BOOL)centered;
/// One line of text centred on the point, both ways, turned about it: its
/// width (-sizeOfText:font:'s) then runs up or down the page. Shorten it to
/// fit first; it is not wrapped.
- (void)drawText:(NSString *)text centeredAt:(NSPoint)point font:(DKFont *)font color:(DKColor)color
        rotation:(DKTextRotation)rotation;
/// Text wrapped at words to the rectangle's width, from its top left;
/// what does not fit its height left out.
- (void)drawText:(NSString *)text inRect:(NSRect)rect font:(DKFont *)font color:(DKColor)color;

@end

/// The length of a dash, and of the gap after it, on a line of the width.
DIAGRAMKIT_EXPORT double DKDashLength(double width);
/// What every surface strokes a path of the style and width with: its
/// dash's and its gap's lengths in @a pattern, and how many (0: solid).
/// Dashed: DKDashLength(width) each; dotted: dots of 1.5 and gaps of 3 at
/// width 1, growing with it.
DIAGRAMKIT_EXPORT NSUInteger DKStrokePattern(DKStrokeStyle style, double width, double pattern[_Nonnull 2]);

NS_ASSUME_NONNULL_END
