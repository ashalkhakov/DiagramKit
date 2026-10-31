/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKForceLayout.h
 *
 * A force-directed layout of shapes that need not form a hierarchy: each
 * spring pulls its two nodes toward its rest length, every node pushes
 * every other away (bigger ones further), a weak pull keeps what nothing
 * links near the middle, and a last pass moves apart what still overlaps.
 * Deterministic: the nodes start on a circle, in the order they were
 * added, so the same graph always comes out the same.
 *
 * A node may be fixed where it is: it pushes and pulls the others but
 * does not move, and the others are laid out around it.
 *
 * Foundation only. ORMKit's ORMSpringLayout, its constants kept.
 */

#import <DiagramKit/DKColor.h>

NS_ASSUME_NONNULL_BEGIN

@interface DKForceLayout : NSObject

/// A node of the size; fixed with its top-left corner at @a origin (an
/// NSValue of NSPoint), or free (nil). A node added twice keeps its first.
- (void)addNode:(NSString *)identifier size:(NSSize)size fixedAt:(nullable NSValue *)origin;
/// A spring between two nodes added, at rest @a rest points apart, centre
/// to centre.
- (void)addSpringFrom:(NSString *)a to:(NSString *)b length:(double)rest;

/// The room left around a layout with no fixed nodes, which is moved so
/// that its top left is this far from (0, 0) (36). Ignored when a node is
/// fixed: then the frames are in the fixed nodes' coordinates.
@property (nonatomic) double margin;
/// The least gap the last pass leaves between two nodes (8).
@property (nonatomic) double gap;

/// Each node's frame (NSValue of NSRect), in flipped coordinates, its
/// origin rounded to whole points.
- (NSDictionary<NSString *, NSValue *> *)layout;

@end

NS_ASSUME_NONNULL_END
