/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKGeometry.h
 *
 * The plane geometry diagrams need: where a line toward a point leaves a
 * shape, how near a point is to a line or a route (for hit testing an
 * edge), a route's length and middle (for its label), and a free spot for
 * a new shape near where it belongs. A route is an array of NSValue of
 * NSPoint, its waypoints, first to last.
 */

#import <DiagramKit/DKColor.h>

NS_ASSUME_NONNULL_BEGIN

/// Where a line from the rectangle's centre toward the point crosses its
/// edge; the centre when the point is the centre.
DIAGRAMKIT_EXPORT NSPoint DKEdgePoint(NSRect rect, NSPoint toward);
/// The distance from @a p to the segment from @a a to @a b.
DIAGRAMKIT_EXPORT double DKDistanceToSegment(NSPoint p, NSPoint a, NSPoint b);
/// The distance from @a p to the nearest of the route's segments (to its
/// one point when it has one); infinity when it has none.
DIAGRAMKIT_EXPORT double DKDistanceToRoute(NSPoint p, NSArray<NSValue *> *route);
DIAGRAMKIT_EXPORT double DKRouteLength(NSArray<NSValue *> *route);
/// The point halfway along the route: where its label goes.
DIAGRAMKIT_EXPORT NSPoint DKRouteMidpoint(NSArray<NSValue *> *route);
/// The smallest rectangle holding the route's points.
DIAGRAMKIT_EXPORT NSRect DKRouteBounds(NSArray<NSValue *> *route);

/// Room for a rectangle of @a size near @a near: centred on it if that is
/// clear of every @a occupied rectangle (NSValue of NSRect) by @a margin,
/// else the first clear place spiralling out from it, never left of or
/// above (0, 0); centred on @a near when there is none within reach.
DIAGRAMKIT_EXPORT NSRect DKFreeSpotNear(NSSize size, NSPoint near, NSArray<NSValue *> *occupied, double margin);

NS_ASSUME_NONNULL_END
