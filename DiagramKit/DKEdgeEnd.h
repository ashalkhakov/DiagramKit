/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKEdgeEnd.h
 *
 * An edge drawn along its route, with what its ends show: arrowheads,
 * UML's triangle and diamonds, or the crow's feet of IE (Martin)
 * notation. An end is drawn at the route's first or last point, pointing
 * into the shape the route meets there, along the route's first or last
 * segment; the line stops where a hollow mark begins, and does not run
 * through a crow's foot's circle.
 *
 * A crow's foot reads outward from the shape: the mark nearest it is the
 * most (a bar, one; the foot, many), the next the least (a bar, one; a
 * circle, zero). So "one" is two bars, "zero or one" a bar and a circle,
 * "one or many" the foot and a bar, "zero or many" the foot and a circle.
 * Sizes grow with the line's width past 1 point; at 1, the foot is 10
 * points long and 12 wide.
 */

#import <DiagramKit/DKSurface.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DKEdgeEnd) {
	DKEdgeEndNone,
	/// A filled arrowhead.
	DKEdgeEndArrow,
	/// Two strokes, a V.
	DKEdgeEndOpenArrow,
	/// A hollow triangle: UML's generalization.
	DKEdgeEndTriangle,
	/// A hollow diamond: UML's aggregation.
	DKEdgeEndDiamond,
	/// A filled diamond: UML's composition.
	DKEdgeEndFilledDiamond,
	DKEdgeEndCrowFootOne,
	DKEdgeEndCrowFootZeroOrOne,
	DKEdgeEndCrowFootMany,
	DKEdgeEndCrowFootOneOrMany,
	DKEdgeEndCrowFootZeroOrMany,
};

/// The route's line (dashed or not), then each end's mark (solid), in the
/// colour and width. A route of fewer than two distinct points draws
/// nothing.
DIAGRAMKIT_EXPORT void DKDrawRoute(id<DKSurface> surface, NSArray<NSValue *> *points, DKColor color, double width,
                                   BOOL dashed, DKEdgeEnd startEnd, DKEdgeEnd endEnd);
/// One end's mark alone: at @a tip, pointing away from @a from.
DIAGRAMKIT_EXPORT void DKDrawEdgeEnd(id<DKSurface> surface, NSPoint tip, NSPoint from, DKEdgeEnd end, DKColor color,
                                     double width);
/// How far back from the tip the end's mark reaches, along the line: room
/// to leave for a label beside it.
DIAGRAMKIT_EXPORT double DKEdgeEndLength(DKEdgeEnd end, double width);

NS_ASSUME_NONNULL_END
