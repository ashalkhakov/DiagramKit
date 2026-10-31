/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKOrthogonalRouter.h
 *
 * Right-angled routes between shapes, as Visio and bpmn.io draw
 * connectors: from the middle of a side of the source (or a point level
 * with the target, to go straight across) to the middle of a side of the
 * target, through lanes beside the shapes in the way. Every way round the
 * router knows -- each pair of sides, straight, one bend, a dogleg through
 * the gap between them, a detour beside each obstacle -- is weighed, and
 * the one that passes through the fewest obstacles wins; of those, the
 * shortest, a bend counting as 20 points of length. Deterministic.
 *
 * A route is an array of NSValue of NSPoint: its first point on the
 * source's edge, its last on the target's, every segment horizontal or
 * vertical, in flipped diagram coordinates.
 *
 * Foundation only. UDWorkflow's flow routing, its BPMN rules (out of a
 * gateway's corner, down out of a boundary event) left to the sides a
 * client allows.
 */

#import <DiagramKit/DKColor.h>

NS_ASSUME_NONNULL_BEGIN

/// The sides of a shape a route may leave or enter by.
typedef NS_OPTIONS(NSUInteger, DKRouteSides) {
	DKRouteSideLeft = 1 << 0,
	DKRouteSideRight = 1 << 1,
	DKRouteSideTop = 1 << 2,
	DKRouteSideBottom = 1 << 3,
	DKRouteSidesHorizontal = DKRouteSideLeft | DKRouteSideRight,
	DKRouteSidesVertical = DKRouteSideTop | DKRouteSideBottom,
	DKRouteSidesAny = DKRouteSidesHorizontal | DKRouteSidesVertical,
};

@interface DKOrthogonalRouter : NSObject

/// A route from any side of @a source to any side of @a target, through
/// as few of the @a obstacles (NSValue of NSRect; not the ends) as it can.
+ (NSArray<NSValue *> *)routeFrom:(NSRect)source to:(NSRect)target avoiding:(NSArray<NSValue *> *)obstacles;
/// The same, leaving and entering only by the sides given (none: any).
+ (NSArray<NSValue *> *)routeFrom:(NSRect)source
                            sides:(DKRouteSides)sourceSides
                               to:(NSRect)target
                            sides:(DKRouteSides)targetSides
                         avoiding:(NSArray<NSValue *> *)obstacles;

/// How many of the obstacles (each grown by 4 points) the route passes
/// through.
+ (NSUInteger)crossingsOfRoute:(NSArray<NSValue *> *)route obstacles:(NSArray<NSValue *> *)obstacles;

/// The route kept when its source moved by @a sourceMoved and its target by
/// @a targetMoved (now at @a source and @a target): its ends moved with
/// them and the bends next to them slid along, so that every segment
/// straight before is straight still; nil when that cannot be (a segment
/// would slant, or a bend would end up inside its shape), or the route has
/// no bend to keep: route it again.
+ (nullable NSArray<NSValue *> *)keptRoute:(NSArray<NSValue *> *)points
                                    source:(NSRect)source
                                    target:(NSRect)target
                               sourceMoved:(NSSize)sourceMoved
                               targetMoved:(NSSize)targetMoved;

@end

NS_ASSUME_NONNULL_END
