/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKLayeredLayout.h"
#include <math.h>

/* The layout is worked out left to right: x along the layers, y across
 * them. Top to bottom is the same with each size transposed going in and
 * each frame coming out. */

/* A node of the layered graph: one of ours, or a placeholder on a long edge. */
@interface DKLayeredNode : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic) NSSize given;
@property (nonatomic) NSSize size;
@property (nonatomic) NSInteger layer;
@property (nonatomic) double order;
/* Its centre across the layers, as the layers are placed. */
@property (nonatomic) double centre;
@property (nonatomic, strong) NSMutableArray<DKLayeredNode *> *successors;
@property (nonatomic, strong) NSMutableArray<DKLayeredNode *> *predecessors;
/* The predecessors whose edge to it leaves from their far side. */
@property (nonatomic, strong) NSHashTable<DKLayeredNode *> *lowered;
/* The predecessors joined to it by an edge reversed to break a cycle: a
 * loop going back, which does not pull it into line. */
@property (nonatomic, strong) NSHashTable<DKLayeredNode *> *looped;
@property (nonatomic, readonly) BOOL isPlaceholder;
@end

@implementation DKLayeredNode

- (instancetype)init
{
	if ((self = [super init])) {
		_successors = [NSMutableArray array];
		_predecessors = [NSMutableArray array];
		_lowered = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
		_looped = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
	}
	return self;
}

- (BOOL)isPlaceholder
{
	return [_identifier hasPrefix:@"\x01"];
}

@end

/* A layer's nodes sorted by their wanted centres (a dictionary by
 * identifier), ties kept in their order: a stable sort. */
static NSInteger
DKCompareByCentre(id a, id b, void *context)
{
	NSDictionary *centre = (__bridge NSDictionary *)context;
	DKLayeredNode *x = a, *y = b;
	double cx = [[centre objectForKey:x.identifier] doubleValue], cy = [[centre objectForKey:y.identifier] doubleValue];
	if (cx != cy) {
		return cx < cy ? NSOrderedAscending : NSOrderedDescending;
	}
	return x.order < y.order ? NSOrderedAscending : x.order > y.order ? NSOrderedDescending : NSOrderedSame;
}

static NSInteger
DKCompareByOrder(id a, id b, void *context)
{
	(void)context;
	DKLayeredNode *x = a, *y = b;
	return x.order < y.order ? NSOrderedAscending : x.order > y.order ? NSOrderedDescending : NSOrderedSame;
}

static NSInteger
DKCompareNumbers(id a, id b, void *context)
{
	(void)context;
	return [(NSNumber *)a compare:(NSNumber *)b];
}

@implementation DKLayeredLayout
{
	NSMutableArray<DKLayeredNode *> *_nodes;
	NSMutableDictionary<NSString *, DKLayeredNode *> *_byId;
	NSMutableArray<NSArray<NSString *> *> *_edges;
	NSMutableSet<NSString *> *_belowEdges;
	NSMutableDictionary<NSString *, NSNumber *> *_layers;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_nodes = [NSMutableArray array];
		_byId = [NSMutableDictionary dictionary];
		_edges = [NSMutableArray array];
		_belowEdges = [NSMutableSet set];
		_layerSpacing = 60;
		_nodeSpacing = 40;
		_sweeps = 12;
	}
	return self;
}

- (void)addNode:(NSString *)identifier size:(NSSize)size
{
	if ([_byId objectForKey:identifier] != nil) {
		return;
	}
	DKLayeredNode *node = [[DKLayeredNode alloc] init];
	node.identifier = identifier;
	node.given = size;
	[_nodes addObject:node];
	[_byId setObject:node forKey:identifier];
}

- (void)addEdgeFrom:(NSString *)source to:(NSString *)target
{
	[self addEdgeFrom:source to:target below:NO];
}

static NSString *
DKEdgeKey(NSString *source, NSString *target)
{
	return [NSString stringWithFormat:@"%@\x02%@", source, target];
}

- (void)addEdgeFrom:(NSString *)source to:(NSString *)target below:(BOOL)below
{
	if (![source isEqualToString:target]) {
		[_edges addObject:@[ source, target ]];
		if (below) {
			[_belowEdges addObject:DKEdgeKey(source, target)];
		}
	}
}

- (NSInteger)layerOf:(NSString *)identifier
{
	NSNumber *layer = [_layers objectForKey:identifier];
	return layer != nil ? [layer integerValue] : -1;
}

#pragma mark Phases

/* A depth-first walk from the node: an edge to a node on the path closes
 * a cycle, and goes into the result reversed, marked so. */
- (void)visit:(NSString *)identifier
          out:(NSDictionary<NSString *, NSArray *> *)out
       onPath:(NSMutableSet *)onPath
         done:(NSMutableSet *)done
       result:(NSMutableArray *)result
{
	[onPath addObject:identifier];
	for (NSString *next in [out objectForKey:identifier]) {
		if ([onPath containsObject:next]) {
			[result addObject:@[ next, identifier, @YES ]];
		} else {
			[result addObject:@[ identifier, next ]];
			if (![done containsObject:next]) {
				[self visit:next out:out onPath:onPath done:done result:result];
			}
		}
	}
	[onPath removeObject:identifier];
	[done addObject:identifier];
}

/* The edges, those closing a cycle reversed: a depth-first walk from the
 * nodes nothing leads to (else from the first), in the order added. */
- (NSArray *)acyclicEdges
{
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	NSMutableSet *hasIncoming = [NSMutableSet set];
	for (NSArray *edge in _edges) {
		NSString *source = [edge objectAtIndex:0], *target = [edge objectAtIndex:1];
		if ([_byId objectForKey:source] == nil || [_byId objectForKey:target] == nil) {
			continue;
		}
		NSMutableArray *list = [out objectForKey:source];
		if (list == nil) {
			list = [NSMutableArray array];
			[out setObject:list forKey:source];
		}
		[list addObject:target];
		[hasIncoming addObject:target];
	}
	NSMutableArray *starts = [NSMutableArray array];
	for (DKLayeredNode *node in _nodes) {
		if (![hasIncoming containsObject:node.identifier]) {
			[starts addObject:node.identifier];
		}
	}
	for (DKLayeredNode *node in _nodes) {
		[starts addObject:node.identifier];
	}
	NSMutableSet *done = [NSMutableSet set], *onPath = [NSMutableSet set];
	NSMutableArray *result = [NSMutableArray array];
	for (NSString *start in starts) {
		if (![done containsObject:start]) {
			[self visit:start out:out onPath:onPath done:done result:result];
		}
	}
	return result;
}

/* Each node's layer: the longest path to it from a node nothing leads to. */
- (void)assignLayers:(NSArray *)edges
{
	NSMutableDictionary *incoming = [NSMutableDictionary dictionary];
	for (DKLayeredNode *node in _nodes) {
		[incoming setObject:@0 forKey:node.identifier];
		node.layer = 0;
	}
	for (NSArray *edge in edges) {
		NSString *sourceId = [edge objectAtIndex:0], *targetId = [edge objectAtIndex:1];
		[incoming setObject:@([[incoming objectForKey:targetId] integerValue] + 1) forKey:targetId];
		DKLayeredNode *source = [_byId objectForKey:sourceId], *target = [_byId objectForKey:targetId];
		[source.successors addObject:target];
		[target.predecessors addObject:source];
		if ([_belowEdges containsObject:DKEdgeKey(sourceId, targetId)]) {
			[target.lowered addObject:source];
		}
		if ([edge count] > 2) {
			[target.looped addObject:source];
		}
	}
	NSMutableArray *ready = [NSMutableArray array];
	for (DKLayeredNode *node in _nodes) {
		if ([[incoming objectForKey:node.identifier] integerValue] == 0) {
			[ready addObject:node];
		}
	}
	while ([ready count] > 0) {
		DKLayeredNode *node = [ready objectAtIndex:0];
		[ready removeObjectAtIndex:0];
		for (DKLayeredNode *next in node.successors) {
			next.layer = MAX(next.layer, node.layer + 1);
			NSInteger left = [[incoming objectForKey:next.identifier] integerValue] - 1;
			[incoming setObject:@(left) forKey:next.identifier];
			if (left == 0) {
				[ready addObject:next];
			}
		}
	}
}

/* An edge across several layers through a placeholder in each between. */
- (NSArray<DKLayeredNode *> *)addPlaceholders
{
	NSMutableArray *all = [NSMutableArray arrayWithArray:_nodes];
	NSInteger count = 0;
	for (DKLayeredNode *node in [_nodes copy]) {
		for (DKLayeredNode *next in [node.successors copy]) {
			if (next.layer - node.layer <= 1) {
				continue;
			}
			BOOL lowered = [next.lowered containsObject:node], looped = [next.looped containsObject:node];
			[node.successors removeObject:next];
			[next.predecessors removeObject:node];
			[next.lowered removeObject:node];
			[next.looped removeObject:node];
			DKLayeredNode *previous = node;
			for (NSInteger layer = node.layer + 1; layer < next.layer; layer++) {
				DKLayeredNode *placeholder = [[DKLayeredNode alloc] init];
				placeholder.identifier = [NSString stringWithFormat:@"\x01%ld", (long)count++];
				placeholder.size = NSMakeSize(0, 10);
				placeholder.layer = layer;
				[previous.successors addObject:placeholder];
				[placeholder.predecessors addObject:previous];
				if (lowered && previous == node) {
					[placeholder.lowered addObject:node];
				}
				if (looped) {
					[placeholder.looped addObject:previous];
				}
				[all addObject:placeholder];
				previous = placeholder;
			}
			[previous.successors addObject:next];
			[next.predecessors addObject:previous];
			if (looped) {
				[next.looped addObject:previous];
			}
		}
	}
	return all;
}

- (NSMutableArray<NSMutableArray<DKLayeredNode *> *> *)layersOf:(NSArray<DKLayeredNode *> *)all
{
	NSMutableArray *layers = [NSMutableArray array];
	for (DKLayeredNode *node in all) {
		while ((NSInteger)[layers count] <= node.layer) {
			[layers addObject:[NSMutableArray array]];
		}
		DKLayeredNode *last = [[layers objectAtIndex:node.layer] lastObject];
		node.order = last != nil ? last.order + 1 : 0;
		[[layers objectAtIndex:node.layer] addObject:node];
	}
	return layers;
}

/* The edges between neighbouring layers that cross. */
static NSInteger
DKLayerCrossings(NSArray<NSArray<DKLayeredNode *> *> *layers)
{
	NSInteger crossings = 0;
	for (NSArray<DKLayeredNode *> *layer in layers) {
		NSUInteger n = 0;
		for (DKLayeredNode *node in layer) {
			n += [node.successors count];
		}
		if (n < 2) {
			continue;
		}
		double *from = malloc(n * sizeof(double)), *to = malloc(n * sizeof(double));
		NSUInteger k = 0;
		for (DKLayeredNode *node in layer) {
			for (DKLayeredNode *next in node.successors) {
				from[k] = node.order;
				to[k] = next.order;
				k++;
			}
		}
		for (NSUInteger i = 0; i < n; i++) {
			for (NSUInteger j = i + 1; j < n; j++) {
				if ((from[i] - from[j]) * (to[i] - to[j]) < 0) {
					crossings++;
				}
			}
		}
		free(from);
		free(to);
	}
	return crossings;
}

- (void)remember:(NSArray *)layers into:(NSMutableDictionary *)bestOrder
{
	for (NSArray *layer in layers) {
		for (DKLayeredNode *node in layer) {
			[bestOrder setObject:@(node.order) forKey:node.identifier];
		}
	}
}

/* Each layer sorted by its nodes' neighbours' average order, sweeping
 * forward and back; the best ordering seen is kept. */
- (void)orderLayers:(NSMutableArray<NSMutableArray<DKLayeredNode *> *> *)layers
{
	NSInteger best = DKLayerCrossings(layers);
	NSMutableDictionary *bestOrder = [NSMutableDictionary dictionary];
	[self remember:layers into:bestOrder];
	/* Sweep even when nothing crosses: the order nodes were added in is
	 * not yet one that follows their neighbours (what hangs below a node
	 * below its other successors). */
	for (NSInteger sweep = 0; sweep < _sweeps && (best > 0 || sweep < 2); sweep++) {
		BOOL forward = sweep % 2 == 0;
		NSInteger count = (NSInteger)[layers count];
		for (NSInteger step = 1; step < count; step++) {
			NSInteger index = forward ? step : count - 1 - step;
			NSMutableArray<DKLayeredNode *> *layer = [layers objectAtIndex:index];
			NSMutableDictionary *centre = [NSMutableDictionary dictionary];
			for (DKLayeredNode *node in layer) {
				/* An edge out of a node's far side puts what it leads to
				 * after the node's other successors; going back, it does
				 * not pull the node. */
				NSUInteger neighbours = 0;
				double sum = 0;
				for (DKLayeredNode *neighbour in forward ? node.predecessors : node.successors) {
					BOOL lowered = forward ? [node.lowered containsObject:neighbour] : [neighbour.lowered containsObject:node];
					if (!forward && lowered) {
						continue;
					}
					neighbours++;
					sum += neighbour.order + (lowered ? 0.5 : 0);
				}
				[centre setObject:@(neighbours > 0 ? sum / neighbours : node.order) forKey:node.identifier];
			}
			[layer sortUsingFunction:DKCompareByCentre context:(__bridge void *)centre];
			for (NSUInteger i = 0; i < [layer count]; i++) {
				[layer objectAtIndex:i].order = i;
			}
		}
		NSInteger crossings = DKLayerCrossings(layers);
		if (crossings <= best) {
			best = crossings;
			[self remember:layers into:bestOrder];
		}
	}
	for (NSMutableArray<DKLayeredNode *> *layer in layers) {
		for (DKLayeredNode *node in layer) {
			node.order = [[bestOrder objectForKey:node.identifier] doubleValue];
		}
		[layer sortUsingFunction:DKCompareByOrder context:NULL];
	}
}

#pragma mark Placing the layers

/* The median of the neighbours' centres, or nil when there are none: of
 * two, their middle, so that a node sits between its branches. */
static NSNumber *
DKMedianCentre(NSArray<NSNumber *> *unsorted)
{
	if ([unsorted count] == 0) {
		return nil;
	}
	NSArray *centres = [unsorted sortedArrayUsingFunction:DKCompareNumbers context:NULL];
	NSUInteger n = [centres count];
	double median = n % 2 == 1 ? [[centres objectAtIndex:n / 2] doubleValue]
		: ([[centres objectAtIndex:n / 2 - 1] doubleValue] + [[centres objectAtIndex:n / 2] doubleValue]) / 2;
	return @(median);
}

/* The layer moved as near as it can be to where each node wants to be,
 * keeping its order and the spacing between its nodes: each node's centre
 * less the room the nodes before it need is then a sequence that may not
 * fall, and the nearest such sequence, in least squares, is found by
 * pooling adjacent values that would (isotonic regression). */
- (void)place:(NSArray<DKLayeredNode *> *)layer towards:(NSArray<NSNumber *> *)wanted
{
	NSUInteger n = [layer count];
	if (n == 0) {
		return;
	}
	double *offsets = malloc(n * sizeof(double)), *targets = malloc(n * sizeof(double));
	double *weights = malloc(n * sizeof(double)), *means = malloc(n * sizeof(double));
	double *blockWeights = malloc(n * sizeof(double));
	NSUInteger *starts = malloc(n * sizeof(NSUInteger));
	double offset = 0;
	for (NSUInteger k = 0; k < n; k++) {
		DKLayeredNode *node = [layer objectAtIndex:k];
		if (k > 0) {
			DKLayeredNode *above = [layer objectAtIndex:k - 1];
			offset += above.size.height / 2 + _nodeSpacing + node.size.height / 2;
		}
		offsets[k] = offset;
		targets[k] = [[wanted objectAtIndex:k] doubleValue] - offset;
		/* A long edge's placeholders hold it straight; a node with many
		 * edges matters more than one with few. */
		weights[k] = node.isPlaceholder ? 2.0 : 1.0 + (double)([node.predecessors count] + [node.successors count]) / 4.0;
	}
	/* Blocks of pooled values: their mean, weight and extent. */
	NSUInteger blocks = 0;
	for (NSUInteger k = 0; k < n; k++) {
		means[blocks] = targets[k];
		blockWeights[blocks] = weights[k];
		starts[blocks] = k;
		blocks++;
		while (blocks > 1 && means[blocks - 2] > means[blocks - 1]) {
			double weight = blockWeights[blocks - 2] + blockWeights[blocks - 1];
			means[blocks - 2] = (means[blocks - 2] * blockWeights[blocks - 2] + means[blocks - 1] * blockWeights[blocks - 1])
				/ weight;
			blockWeights[blocks - 2] = weight;
			blocks--;
		}
	}
	for (NSUInteger b = 0; b < blocks; b++) {
		NSUInteger to = b + 1 < blocks ? starts[b + 1] : n;
		for (NSUInteger k = starts[b]; k < to; k++) {
			[[layer objectAtIndex:k] setCentre:means[b] + offsets[k]];
		}
	}
	free(offsets);
	free(targets);
	free(weights);
	free(means);
	free(blockWeights);
	free(starts);
}

/* Each layer packed, then moved, sweep by sweep, towards its neighbours in
 * the layer before it and then in the layer after it: a node level with
 * the node it follows, a node between its branches, so that edges run
 * straight where they can. */
- (void)placeAcross:(NSArray<NSArray<DKLayeredNode *> *> *)layers
{
	for (NSArray<DKLayeredNode *> *layer in layers) {
		double y = 0;
		for (DKLayeredNode *node in layer) {
			node.centre = y + node.size.height / 2;
			y += node.size.height + _nodeSpacing;
		}
	}
	NSUInteger count = [layers count];
	for (NSInteger sweep = 0; sweep < MAX((NSInteger)4, _sweeps / 2); sweep++) {
		for (NSUInteger pass = 0; pass < 2; pass++) {
			BOOL forward = pass == 0;
			for (NSUInteger step = 1; step < count; step++) {
				NSArray<DKLayeredNode *> *layer = [layers objectAtIndex:forward ? step : count - 1 - step];
				NSMutableArray *wanted = [NSMutableArray array];
				for (DKLayeredNode *node in layer) {
					/* After a node whose far side an edge leaves: a row further. */
					NSMutableArray *centres = [NSMutableArray array];
					double floor = -1.0e9;
					for (DKLayeredNode *predecessor in node.predecessors) {
						if ([node.lowered containsObject:predecessor]) {
							floor = MAX(floor, predecessor.centre + predecessor.size.height / 2 + _nodeSpacing
							                       + node.size.height / 2);
						}
					}
					for (DKLayeredNode *neighbour in forward ? node.predecessors : node.successors) {
						BOOL lowered = forward ? [node.lowered containsObject:neighbour] : [neighbour.lowered containsObject:node];
						BOOL looped = forward ? [node.looped containsObject:neighbour] : [neighbour.looped containsObject:node];
						if (looped) {
							continue;
						}
						if (!lowered) {
							[centres addObject:@(neighbour.centre)];
						} else if (forward) {
							[centres addObject:@(neighbour.centre + neighbour.size.height / 2 + _nodeSpacing
							                     + node.size.height / 2)];
						}
					}
					NSNumber *median = DKMedianCentre(centres);
					/* After what it hangs from, whatever follows it. */
					[wanted addObject:@(MAX(median != nil ? [median doubleValue] : node.centre, floor))];
				}
				[self place:layer towards:wanted];
			}
		}
	}
	/* Last, what hangs off a node's far side is put after where the node
	 * ended up, and what follows only it goes with it; the rest stays. */
	NSHashTable *moved = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
	for (NSUInteger index = 1; index < count; index++) {
		NSArray<DKLayeredNode *> *layer = [layers objectAtIndex:index];
		NSMutableArray *wanted = [NSMutableArray array];
		NSMutableArray *before = [NSMutableArray array];
		for (DKLayeredNode *node in layer) {
			double want = node.centre;
			NSArray *ahead = node.predecessors;
			for (DKLayeredNode *predecessor in ahead) {
				if ([node.lowered containsObject:predecessor]) {
					want = MAX(want, predecessor.centre + predecessor.size.height / 2 + _nodeSpacing + node.size.height / 2);
				} else if ([ahead count] == 1 && [moved containsObject:predecessor]) {
					want = predecessor.centre;
				}
			}
			[wanted addObject:@(want)];
			[before addObject:@(node.centre)];
		}
		[self place:layer towards:wanted];
		for (NSUInteger k = 0; k < [layer count]; k++) {
			if (fabs([layer objectAtIndex:k].centre - [[before objectAtIndex:k] doubleValue]) > 0.5) {
				[moved addObject:[layer objectAtIndex:k]];
			}
		}
	}
}

- (NSDictionary<NSString *, NSValue *> *)layout
{
	BOOL across = _direction == DKLayoutTopToBottom;
	for (DKLayeredNode *node in _nodes) {
		[node.successors removeAllObjects];
		[node.predecessors removeAllObjects];
		[node.lowered removeAllObjects];
		[node.looped removeAllObjects];
		node.size = across ? NSMakeSize(node.given.height, node.given.width) : node.given;
	}
	[self assignLayers:[self acyclicEdges]];
	NSArray *all = [self addPlaceholders];
	NSMutableArray<NSMutableArray<DKLayeredNode *> *> *layers = [self layersOf:all];
	[self orderLayers:layers];

	/* Columns as wide as their widest node. */
	double x = 0;
	NSUInteger layerCount = [layers count];
	double *columnX = malloc(MAX((NSUInteger)1, layerCount) * sizeof(double));
	double *columnWidth = malloc(MAX((NSUInteger)1, layerCount) * sizeof(double));
	for (NSUInteger i = 0; i < layerCount; i++) {
		double width = 0;
		for (DKLayeredNode *node in [layers objectAtIndex:i]) {
			width = MAX(width, node.size.width);
		}
		columnX[i] = x;
		columnWidth[i] = width;
		x += width + _layerSpacing;
	}
	[self placeAcross:layers];
	double top = 0, bottom = 0;
	BOOL first = YES;
	for (NSArray<DKLayeredNode *> *layer in layers) {
		for (DKLayeredNode *node in layer) {
			double nodeTop = node.centre - node.size.height / 2, nodeBottom = node.centre + node.size.height / 2;
			top = first ? nodeTop : MIN(top, nodeTop);
			bottom = first ? nodeBottom : MAX(bottom, nodeBottom);
			first = NO;
		}
	}
	NSMutableDictionary *frames = [NSMutableDictionary dictionary];
	_layers = [NSMutableDictionary dictionary];
	for (NSUInteger i = 0; i < layerCount; i++) {
		for (DKLayeredNode *node in [layers objectAtIndex:i]) {
			if (node.isPlaceholder) {
				continue;
			}
			double left = round(columnX[i] + (columnWidth[i] - node.size.width) / 2);
			double y = round(node.centre - node.size.height / 2 - top);
			NSRect frame = across ? NSMakeRect(y, left, node.given.width, node.given.height)
			                      : NSMakeRect(left, y, node.given.width, node.given.height);
			[frames setObject:[NSValue valueWithRect:frame] forKey:node.identifier];
			[_layers setObject:@(node.layer) forKey:node.identifier];
		}
	}
	free(columnX);
	free(columnWidth);
	NSSize extent = NSMakeSize(MAX(0, x - _layerSpacing), bottom - top);
	_size = across ? NSMakeSize(extent.height, extent.width) : extent;
	return frames;
}

@end
