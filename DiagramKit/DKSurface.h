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

@protocol DKSurface <NSObject>

/// The text's width and line height in the font, as this surface sets it.
- (NSSize)sizeOfText:(NSString *)text font:(DKFont *)font;
/// Dashed: dashes and gaps of DKDashLength(width).
- (void)strokePath:(DKPath *)path color:(DKColor)color width:(double)width dashed:(BOOL)dashed;
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

/// The length of a dash, and of the gap after it, on a line of the width:
/// what every surface strokes a dashed path with.
DIAGRAMKIT_EXPORT double DKDashLength(double width);

NS_ASSUME_NONNULL_END
