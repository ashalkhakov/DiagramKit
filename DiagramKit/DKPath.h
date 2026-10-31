/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKPath.h
 *
 * A path to stroke or fill on a surface (DKSurface): moves, lines, cubic
 * curves and closes, in diagram points, flipped (y grows downward). A
 * rectangle, rounded rectangle or oval made by its constructor remembers
 * what it is, so a surface that has the shape natively (SVG's <rect> and
 * <ellipse>, NSBezierPath's) draws it so; its elements describe it too, for
 * one that has not. Adding to such a path makes it a plain one.
 */

#import <DiagramKit/DKColor.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DKPathElement) {
	DKPathMoveTo,
	DKPathLineTo,
	/// Its points: the first control point, the second, the end.
	DKPathCurveTo,
	DKPathClose,
};

/// What a path is, when its constructor made a shape of it.
typedef NS_ENUM(NSInteger, DKPathShape) {
	DKPathShapeNone,
	DKPathShapeRect,
	DKPathShapeRoundedRect,
	DKPathShapeOval,
};

@interface DKPath : NSObject <NSCopying>

+ (instancetype)path;
+ (instancetype)pathWithRect:(NSRect)rect;
/// Corners rounded by @a radius, at most half the shorter side.
+ (instancetype)pathWithRoundedRect:(NSRect)rect radius:(double)radius;
+ (instancetype)pathWithOvalInRect:(NSRect)rect;
/// An open polyline through the points (NSValue of NSPoint).
+ (instancetype)pathWithPoints:(NSArray<NSValue *> *)points;
+ (instancetype)pathWithLineFrom:(NSPoint)from to:(NSPoint)to;

- (void)moveTo:(NSPoint)point;
- (void)lineTo:(NSPoint)point;
- (void)curveTo:(NSPoint)point control1:(NSPoint)control1 control2:(NSPoint)control2;
- (void)close;
/// The other path's elements after this one's.
- (void)appendPath:(DKPath *)path;

@property (nonatomic, readonly) NSUInteger elementCount;
/// The element at @a index; its points into @a points (room for three:
/// one for a move or line, three for a curve, none for a close).
- (DKPathElement)elementAtIndex:(NSUInteger)index points:(nullable NSPoint *)points;

/// The smallest rectangle holding every point, curves' control points
/// among them; NSZeroRect when empty.
@property (nonatomic, readonly) NSRect bounds;
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

/// A shape's kind, rectangle and corner radius; DKPathShapeNone,
/// NSZeroRect and 0 for a plain path.
@property (nonatomic, readonly) DKPathShape shape;
@property (nonatomic, readonly) NSRect shapeRect;
@property (nonatomic, readonly) double radius;

@end

NS_ASSUME_NONNULL_END
