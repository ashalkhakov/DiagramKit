/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKAppKitSurface.h"

NSColor *
DKNSColor(DKColor color)
{
	return [NSColor colorWithCalibratedRed:color.r green:color.g blue:color.b alpha:color.a];
}

NSFont *
DKNSFont(DKFont *spec)
{
	double size = spec.size > 0 ? spec.size : [NSFont systemFontSize];
	NSFont *font = nil;
	if ([spec.name length] > 0) {
		font = [NSFont fontWithName:spec.name size:size];
		if (font != nil && spec.bold) {
			NSFont *bold = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
			font = bold ?: font;
		}
	}
	if (font == nil) {
		font = spec.bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
	}
	return font;
}

NSBezierPath *
DKBezierPath(DKPath *path)
{
	switch (path.shape) {
	case DKPathShapeRect:
		return [NSBezierPath bezierPathWithRect:path.shapeRect];
	case DKPathShapeRoundedRect:
		return [NSBezierPath bezierPathWithRoundedRect:path.shapeRect xRadius:path.radius yRadius:path.radius];
	case DKPathShapeOval:
		return [NSBezierPath bezierPathWithOvalInRect:path.shapeRect];
	case DKPathShapeNone:
		break;
	}
	NSBezierPath *bezier = [NSBezierPath bezierPath];
	NSPoint p[3];
	for (NSUInteger i = 0; i < path.elementCount; i++) {
		switch ([path elementAtIndex:i points:p]) {
		case DKPathMoveTo:
			[bezier moveToPoint:p[0]];
			break;
		case DKPathLineTo:
			[bezier lineToPoint:p[0]];
			break;
		case DKPathCurveTo:
			[bezier curveToPoint:p[2] controlPoint1:p[0] controlPoint2:p[1]];
			break;
		case DKPathClose:
			[bezier closePath];
			break;
		}
	}
	return bezier;
}

@implementation DKAppKitSurface

+ (instancetype)surface
{
	return [[self alloc] init];
}

- (NSDictionary *)attributesFor:(DKFont *)font color:(DKColor)color
{
	return @{ NSFontAttributeName: DKNSFont(font), NSForegroundColorAttributeName: DKNSColor(color) };
}

- (NSSize)sizeOfText:(NSString *)text font:(DKFont *)font
{
	return [text sizeWithAttributes:@{ NSFontAttributeName: DKNSFont(font) }];
}

- (void)strokePath:(DKPath *)path color:(DKColor)color width:(double)width dashed:(BOOL)dashed
{
	if (path.empty) {
		return;
	}
	NSBezierPath *bezier = DKBezierPath(path);
	[DKNSColor(color) setStroke];
	[bezier setLineWidth:width];
	if (dashed) {
		CGFloat length = DKDashLength(width);
		CGFloat pattern[2] = { length, length };
		[bezier setLineDash:pattern count:2 phase:0];
	}
	[bezier stroke];
}

- (void)fillPath:(DKPath *)path color:(DKColor)color
{
	if (path.empty) {
		return;
	}
	[DKNSColor(color) setFill];
	[DKBezierPath(path) fill];
}

- (void)drawText:(NSString *)text at:(NSPoint)point font:(DKFont *)font color:(DKColor)color centered:(BOOL)centered
{
	if ([text length] == 0) {
		return;
	}
	NSDictionary *attributes = [self attributesFor:font color:color];
	if (centered) {
		point.x -= [text sizeWithAttributes:attributes].width / 2;
	}
	[text drawAtPoint:point withAttributes:attributes];
}

- (void)drawText:(NSString *)text centeredAt:(NSPoint)point font:(DKFont *)font color:(DKColor)color
        rotation:(DKTextRotation)rotation
{
	if ([text length] == 0) {
		return;
	}
	NSDictionary *attributes = [self attributesFor:font color:color];
	NSSize size = [text sizeWithAttributes:attributes];
	/* Turned about the point; in the flipped view -90 is anticlockwise. */
	[NSGraphicsContext saveGraphicsState];
	NSAffineTransform *turn = [NSAffineTransform transform];
	[turn translateXBy:point.x yBy:point.y];
	if (rotation != DKTextRotationNone) {
		[turn rotateByDegrees:rotation == DKTextRotationQuarterAnticlockwise ? -90 : 90];
	}
	[turn concat];
	[text drawAtPoint:NSMakePoint(-size.width / 2, -size.height / 2) withAttributes:attributes];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect font:(DKFont *)font color:(DKColor)color
{
	if ([text length] == 0) {
		return;
	}
	[text drawInRect:rect withAttributes:[self attributesFor:font color:color]];
}

@end
