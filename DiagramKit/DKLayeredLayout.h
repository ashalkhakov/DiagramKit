/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKLayeredLayout.h
 *
 * A layered (Sugiyama) layout of a directed graph, its edges running one
 * way: left to right, as a process reads, or top to bottom, as a hierarchy
 * does. Cycles are broken by reversing the edges that close them, nodes
 * are put in layers by their longest path from a start, an edge across
 * several layers goes through placeholders, the layers are ordered to
 * cross as few edges as their neighbours' average positions allow, and
 * then they are spaced by the nodes' sizes, each node as near as it can be
 * to the median of its neighbours. Deterministic: ties go by the order the
 * nodes were added in.
 *
 * Foundation only. UDWorkflow's WKDLayout, generalized to either direction.
 */

#import <DiagramKit/DKColor.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DKLayoutDirection) {
	/// Layers are columns; an edge runs rightward.
	DKLayoutLeftToRight,
	/// Layers are rows; an edge runs downward.
	DKLayoutTopToBottom,
};

@interface DKLayeredLayout : NSObject

/// Nodes in the order they are added: the order ties are broken in. A
/// node added twice keeps its first size.
- (void)addNode:(NSString *)identifier size:(NSSize)size;
/// An edge between nodes added (before -layout runs); a loop on one node
/// is ignored.
- (void)addEdgeFrom:(NSString *)source to:(NSString *)target;
/// An edge out of the source's far side across the layer (its bottom left
/// to right, its right top to bottom) -- a BPMN boundary event's flow:
/// what it leads to goes after the source's other successors, a row
/// further.
- (void)addEdgeFrom:(NSString *)source to:(NSString *)target below:(BOOL)below;

/// DKLayoutLeftToRight unless set.
@property (nonatomic) DKLayoutDirection direction;
/// Between the layers (60), and between the nodes of a layer (40).
@property (nonatomic) double layerSpacing;
@property (nonatomic) double nodeSpacing;
/// The ordering passes, forward and back (12).
@property (nonatomic) NSInteger sweeps;

/// Each node's frame (NSValue of NSRect): its top-left corner, in flipped
/// coordinates from (0, 0) at the layout's top left, and its size.
- (NSDictionary<NSString *, NSValue *> *)layout;
/// The extent of the last layout.
@property (nonatomic, readonly) NSSize size;
/// The layer the last layout put the node in, from 0; -1 for none.
- (NSInteger)layerOf:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
