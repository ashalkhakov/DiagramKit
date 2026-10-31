/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKForceLayout.h"
#include <float.h>
#include <math.h>

/* A node of the layout: where it is, and how big. */
typedef struct {
	double x, y;   /* centre */
	double dx, dy; /* this round's displacement */
	double w, h;
	BOOL fixed;
} DKForceNode;

typedef struct {
	NSUInteger i, j;
	double rest;
} DKSpring;

/* The nodes laid out, force-directed, about the centre: each spring pulls
 * its two together, everything pushes everything else away, and a last
 * pass moves apart what still overlaps. The free nodes start on a circle
 * about the centre, in their order; fixed ones stay where they are. */
static void
DKSpringLayout(DKForceNode *nodes, NSUInteger count, DKSpring *springs, NSUInteger springCount, NSPoint centre,
               double gap)
{
	NSUInteger freeCount = 0;
	for (NSUInteger i = 0; i < count; i++) {
		freeCount += nodes[i].fixed ? 0 : 1;
	}
	if (freeCount == 0) {
		return;
	}
	double radius = MAX(2.0 * 72, sqrt((double)count) * 0.9 * 72);
	for (NSUInteger i = 0; i < count; i++) {
		if (!nodes[i].fixed) {
			double angle = 2 * M_PI * i / count;
			nodes[i].x = centre.x + radius * cos(angle);
			nodes[i].y = centre.y + radius * sin(angle);
		}
	}
	/* The distance shapes settle at: about NORMA's spacing. */
	double k = 0.75 * 72;
	double temperature = radius / 3;
	for (NSUInteger round = 0; round < 400; round++) {
		for (NSUInteger i = 0; i < count; i++) {
			nodes[i].dx = 0;
			nodes[i].dy = 0;
		}
		for (NSUInteger i = 0; i < count; i++) {
			for (NSUInteger j = i + 1; j < count; j++) {
				double ddx = nodes[i].x - nodes[j].x;
				double ddy = nodes[i].y - nodes[j].y;
				double distance = MAX(hypot(ddx, ddy), 1.0);
				/* Bigger shapes keep further apart. */
				double reach = k * 0.6 + (nodes[i].w + nodes[j].w) / 4;
				double force = reach * reach / distance;
				nodes[i].dx += ddx / distance * force;
				nodes[i].dy += ddy / distance * force;
				nodes[j].dx -= ddx / distance * force;
				nodes[j].dy -= ddy / distance * force;
			}
		}
		for (NSUInteger s = 0; s < springCount; s++) {
			NSUInteger i = springs[s].i;
			NSUInteger j = springs[s].j;
			double ddx = nodes[i].x - nodes[j].x;
			double ddy = nodes[i].y - nodes[j].y;
			double distance = MAX(hypot(ddx, ddy), 1.0);
			double stretch = distance - springs[s].rest;
			double force = 2.0 * stretch * fabs(stretch) / k;
			nodes[i].dx -= ddx / distance * force;
			nodes[i].dy -= ddy / distance * force;
			nodes[j].dx += ddx / distance * force;
			nodes[j].dy += ddy / distance * force;
		}
		/* A weak pull to the middle, so what nothing links stays near. */
		for (NSUInteger i = 0; i < count; i++) {
			nodes[i].dx -= (nodes[i].x - centre.x) * 0.03;
			nodes[i].dy -= (nodes[i].y - centre.y) * 0.03;
		}
		for (NSUInteger i = 0; i < count; i++) {
			if (nodes[i].fixed) {
				continue;
			}
			double length = MAX(hypot(nodes[i].dx, nodes[i].dy), 0.0001);
			double step = MIN(length, temperature);
			nodes[i].x += nodes[i].dx / length * step;
			nodes[i].y += nodes[i].dy / length * step;
		}
		temperature = MAX(temperature * 0.985, 1.0);
	}
	/* What still overlaps, pushed apart along the shorter way out; a fixed
	 * node's share is the other's. */
	for (NSUInteger pass = 0; pass < 200; pass++) {
		BOOL moved = NO;
		for (NSUInteger i = 0; i < count; i++) {
			for (NSUInteger j = i + 1; j < count; j++) {
				if (nodes[i].fixed && nodes[j].fixed) {
					continue;
				}
				double overlapX = (nodes[i].w + nodes[j].w) / 2 + gap - fabs(nodes[i].x - nodes[j].x);
				double overlapY = (nodes[i].h + nodes[j].h) / 2 + gap - fabs(nodes[i].y - nodes[j].y);
				if (overlapX <= 0 || overlapY <= 0) {
					continue;
				}
				moved = YES;
				double shareI = nodes[i].fixed ? 0 : nodes[j].fixed ? 1 : 0.5;
				double shareJ = 1 - shareI;
				if (overlapX < overlapY) {
					double sign = nodes[i].x < nodes[j].x || (nodes[i].x == nodes[j].x && i < j) ? -1 : 1;
					nodes[i].x += sign * overlapX * shareI;
					nodes[j].x -= sign * overlapX * shareJ;
				} else {
					double sign = nodes[i].y < nodes[j].y || (nodes[i].y == nodes[j].y && i < j) ? -1 : 1;
					nodes[i].y += sign * overlapY * shareI;
					nodes[j].y -= sign * overlapY * shareJ;
				}
			}
		}
		if (!moved) {
			break;
		}
	}
}

@implementation DKForceLayout
{
	NSMutableArray<NSString *> *_identifiers;
	NSMutableDictionary<NSString *, NSNumber *> *_index;
	NSMutableArray<NSValue *> *_sizes;
	NSMutableArray *_origins;
	NSMutableArray<NSArray *> *_springs;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_identifiers = [NSMutableArray array];
		_index = [NSMutableDictionary dictionary];
		_sizes = [NSMutableArray array];
		_origins = [NSMutableArray array];
		_springs = [NSMutableArray array];
		_margin = 0.5 * 72;
		_gap = 8;
	}
	return self;
}

- (void)addNode:(NSString *)identifier size:(NSSize)size fixedAt:(NSValue *)origin
{
	if ([_index objectForKey:identifier] != nil) {
		return;
	}
	[_index setObject:@([_identifiers count]) forKey:identifier];
	[_identifiers addObject:[identifier copy]];
	[_sizes addObject:[NSValue valueWithSize:size]];
	[_origins addObject:origin ?: [NSNull null]];
}

- (void)addSpringFrom:(NSString *)a to:(NSString *)b length:(double)rest
{
	[_springs addObject:@[ a, b, @(rest) ]];
}

- (NSDictionary<NSString *, NSValue *> *)layout
{
	NSUInteger count = [_identifiers count];
	if (count == 0) {
		return @{};
	}
	DKForceNode *nodes = calloc(count, sizeof(DKForceNode));
	DKSpring *springs = calloc(MAX((NSUInteger)1, [_springs count]), sizeof(DKSpring));
	BOOL anyFixed = NO;
	double fixedX = 0, fixedY = 0;
	NSUInteger fixedCount = 0;
	for (NSUInteger i = 0; i < count; i++) {
		NSSize size = [[_sizes objectAtIndex:i] sizeValue];
		nodes[i].w = size.width;
		nodes[i].h = size.height;
		id origin = [_origins objectAtIndex:i];
		if ([origin isKindOfClass:[NSValue class]]) {
			NSPoint at = [origin pointValue];
			nodes[i].fixed = YES;
			nodes[i].x = at.x + size.width / 2;
			nodes[i].y = at.y + size.height / 2;
			fixedX += nodes[i].x;
			fixedY += nodes[i].y;
			fixedCount++;
			anyFixed = YES;
		}
	}
	NSUInteger springCount = 0;
	for (NSArray *spring in _springs) {
		NSNumber *i = [_index objectForKey:[spring objectAtIndex:0]];
		NSNumber *j = [_index objectForKey:[spring objectAtIndex:1]];
		if (i == nil || j == nil || [i isEqual:j]) {
			continue;
		}
		springs[springCount].i = [i unsignedIntegerValue];
		springs[springCount].j = [j unsignedIntegerValue];
		springs[springCount].rest = [[spring objectAtIndex:2] doubleValue];
		springCount++;
	}
	NSPoint centre = anyFixed ? NSMakePoint(fixedX / fixedCount, fixedY / fixedCount) : NSZeroPoint;
	DKSpringLayout(nodes, count, springs, springCount, centre, _gap);
	/* Moved to the top left, the margin in; or left where the fixed nodes
	 * have it. */
	double shiftX = 0, shiftY = 0;
	if (!anyFixed) {
		double minX = DBL_MAX, minY = DBL_MAX;
		for (NSUInteger i = 0; i < count; i++) {
			minX = MIN(minX, nodes[i].x - nodes[i].w / 2);
			minY = MIN(minY, nodes[i].y - nodes[i].h / 2);
		}
		shiftX = _margin - minX;
		shiftY = _margin - minY;
	}
	NSMutableDictionary *frames = [NSMutableDictionary dictionary];
	for (NSUInteger i = 0; i < count; i++) {
		NSRect frame;
		if (nodes[i].fixed) {
			NSPoint at = [[_origins objectAtIndex:i] pointValue];
			frame = NSMakeRect(at.x, at.y, nodes[i].w, nodes[i].h);
		} else {
			frame = NSMakeRect(round(nodes[i].x + shiftX - nodes[i].w / 2), round(nodes[i].y + shiftY - nodes[i].h / 2),
			                   nodes[i].w, nodes[i].h);
		}
		[frames setObject:[NSValue valueWithRect:frame] forKey:[_identifiers objectAtIndex:i]];
	}
	free(nodes);
	free(springs);
	return frames;
}

@end
