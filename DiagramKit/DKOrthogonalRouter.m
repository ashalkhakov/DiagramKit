/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKOrthogonalRouter.h"
#include <math.h>

/* How far a route runs straight out of a side before it may turn, how far
 * a lane keeps from the shape it passes, and what a bend costs, in points
 * of length. */
static const double DKStub = 20.0;
static const double DKClearance = 12.0;
static const double DKBendCost = 20.0;
/* How much two facing sides must share for a straight route between
 * them: room for a crow's foot's toes. */
static const double DKLeastShared = 16.0;
/* How much an obstacle is grown by, for a route to count as through it. */
static const double DKObstacleGrowth = 4.0;

static const DKRouteSides DKSideOrder[4] = { DKRouteSideRight, DKRouteSideBottom, DKRouteSideLeft, DKRouteSideTop };

static NSPoint
DKSideMiddle(NSRect r, DKRouteSides side)
{
	switch (side) {
	case DKRouteSideLeft:
		return NSMakePoint(NSMinX(r), NSMidY(r));
	case DKRouteSideRight:
		return NSMakePoint(NSMaxX(r), NSMidY(r));
	case DKRouteSideTop:
		return NSMakePoint(NSMidX(r), NSMinY(r));
	default:
		return NSMakePoint(NSMidX(r), NSMaxY(r));
	}
}

/* The side's outward direction. */
static NSPoint
DKSideNormal(DKRouteSides side)
{
	switch (side) {
	case DKRouteSideLeft:
		return NSMakePoint(-1, 0);
	case DKRouteSideRight:
		return NSMakePoint(1, 0);
	case DKRouteSideTop:
		return NSMakePoint(0, -1);
	default:
		return NSMakePoint(0, 1);
	}
}

static BOOL
DKSame(NSPoint a, NSPoint b)
{
	return fabs(a.x - b.x) < 0.01 && fabs(a.y - b.y) < 0.01;
}

/* Whether a horizontal or vertical segment passes through the rectangle. */
static BOOL
DKSegmentCrosses(NSPoint a, NSPoint b, NSRect rect)
{
	NSRect segment = NSMakeRect(MIN(a.x, b.x), MIN(a.y, b.y), fabs(a.x - b.x), fabs(a.y - b.y));
	return NSIntersectsRect(NSInsetRect(segment, -0.5, -0.5), rect);
}

static NSUInteger
DKCrossings(const NSPoint *p, NSUInteger count, NSArray<NSValue *> *obstacles)
{
	NSUInteger crossings = 0;
	for (NSValue *obstacle in obstacles) {
		NSRect rect = NSInsetRect([obstacle rectValue], -DKObstacleGrowth, -DKObstacleGrowth);
		for (NSUInteger i = 1; i < count; i++) {
			if (DKSegmentCrosses(p[i - 1], p[i], rect)) {
				crossings++;
				break;
			}
		}
	}
	return crossings;
}

/* The points with repeats dropped, and each point in the middle of a
 * straight run: the corners alone. A run that doubles back keeps its
 * turning point, for the check to refuse. */
static NSUInteger
DKSimplify(NSPoint *p, NSUInteger count)
{
	BOOL changed = YES;
	while (changed) {
		changed = NO;
		NSUInteger n = 0;
		for (NSUInteger i = 0; i < count; i++) {
			if (n > 0 && DKSame(p[n - 1], p[i])) {
				changed = YES;
				continue;
			}
			p[n++] = p[i];
		}
		count = n;
		n = 0;
		for (NSUInteger i = 0; i < count; i++) {
			if (n > 0 && i + 1 < count) {
				NSPoint a = p[n - 1], b = p[i], c = p[i + 1];
				BOOL level = fabs(a.y - b.y) < 0.01 && fabs(b.y - c.y) < 0.01;
				BOOL plumb = fabs(a.x - b.x) < 0.01 && fabs(b.x - c.x) < 0.01;
				BOOL between = (b.x - a.x) * (c.x - b.x) >= 0 && (b.y - a.y) * (c.y - b.y) >= 0;
				if ((level || plumb) && between) {
					changed = YES;
					continue;
				}
			}
			p[n++] = p[i];
		}
		count = n;
	}
	return count;
}

static NSPoint
DKDirection(NSPoint a, NSPoint b)
{
	double length = hypot(b.x - a.x, b.y - a.y);
	return length > 0 ? NSMakePoint((b.x - a.x) / length, (b.y - a.y) / length) : NSZeroPoint;
}

/* A route the router may take: every segment straight and none doubling
 * back, out of the source's side and into the target's, and through
 * neither. */
static BOOL
DKAcceptable(const NSPoint *p, NSUInteger count, NSRect s, NSPoint outOfSource, NSRect t, NSPoint intoTarget)
{
	if (count < 2) {
		return NO;
	}
	for (NSUInteger i = 1; i < count; i++) {
		if (fabs(p[i].x - p[i - 1].x) > 0.01 && fabs(p[i].y - p[i - 1].y) > 0.01) {
			return NO;
		}
		if (i > 1) {
			NSPoint d0 = DKDirection(p[i - 2], p[i - 1]), d1 = DKDirection(p[i - 1], p[i]);
			if (d0.x * d1.x + d0.y * d1.y < -0.5) {
				return NO;
			}
		}
	}
	NSPoint first = DKDirection(p[0], p[1]), last = DKDirection(p[count - 2], p[count - 1]);
	if (first.x * outOfSource.x + first.y * outOfSource.y < 0.99 || last.x * intoTarget.x + last.y * intoTarget.y < 0.99) {
		return NO;
	}
	NSRect sInside = NSInsetRect(s, 1, 1), tInside = NSInsetRect(t, 1, 1);
	for (NSUInteger i = 1; i < count; i++) {
		if (DKSegmentCrosses(p[i - 1], p[i], sInside) || DKSegmentCrosses(p[i - 1], p[i], tInside)) {
			return NO;
		}
	}
	return YES;
}

static double
DKCost(const NSPoint *p, NSUInteger count)
{
	double length = 0;
	for (NSUInteger i = 1; i < count; i++) {
		length += fabs(p[i].x - p[i - 1].x) + fabs(p[i].y - p[i - 1].y);
	}
	return length + DKBendCost * (double)(count - 2);
}

/* The best route so far, and what it costs. */
typedef struct {
	NSPoint points[8];
	NSUInteger count;
	NSUInteger crossings;
	double cost;
	BOOL found;
} DKBest;

static void
DKConsider(DKBest *best, NSPoint *p, NSUInteger count, NSRect s, NSPoint outOfSource, NSRect t, NSPoint intoTarget,
           NSArray<NSValue *> *obstacles)
{
	count = DKSimplify(p, count);
	if (count > 8 || !DKAcceptable(p, count, s, outOfSource, t, intoTarget)) {
		return;
	}
	NSUInteger crossings = DKCrossings(p, count, obstacles);
	if (best->found && crossings > best->crossings) {
		return;
	}
	double cost = DKCost(p, count);
	if (best->found && crossings == best->crossings && cost >= best->cost - 0.001) {
		return;
	}
	memcpy(best->points, p, count * sizeof(NSPoint));
	best->count = count;
	best->crossings = crossings;
	best->cost = cost;
	best->found = YES;
}

/* Lanes a route may run along, across one axis: beside each shape, and in
 * the gap between the ends. */
static NSArray<NSNumber *> *
DKLanes(NSRect s, NSRect t, NSArray<NSValue *> *obstacles, BOOL vertical)
{
	NSMutableArray *values = [NSMutableArray array];
	NSMutableArray *rects = [NSMutableArray arrayWithObjects:[NSValue valueWithRect:s], [NSValue valueWithRect:t], nil];
	[rects addObjectsFromArray:obstacles];
	for (NSValue *value in rects) {
		NSRect r = [value rectValue];
		[values addObject:@(vertical ? NSMinX(r) - DKClearance : NSMinY(r) - DKClearance)];
		[values addObject:@(vertical ? NSMaxX(r) + DKClearance : NSMaxY(r) + DKClearance)];
	}
	double sMin = vertical ? NSMinX(s) : NSMinY(s), sMax = vertical ? NSMaxX(s) : NSMaxY(s);
	double tMin = vertical ? NSMinX(t) : NSMinY(t), tMax = vertical ? NSMaxX(t) : NSMaxY(t);
	if (sMax < tMin) {
		[values addObject:@((sMax + tMin) / 2)];
		[values addObject:@(sMax + DKStub)];
		[values addObject:@(tMin - DKStub)];
	} else if (tMax < sMin) {
		[values addObject:@((tMax + sMin) / 2)];
		[values addObject:@(tMax + DKStub)];
		[values addObject:@(sMin - DKStub)];
	}
	NSMutableArray *lanes = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for (NSNumber *value in values) {
		NSNumber *key = @(round([value doubleValue] * 2) / 2);
		if (![seen containsObject:key]) {
			[seen addObject:key];
			[lanes addObject:value];
		}
	}
	return lanes;
}

/* Where a straight route between facing sides runs, when the shapes
 * overlap across it, by enough: level with the source's middle if it can
 * be, else with the target's, else the middle of what they share. */
static BOOL
DKSharedLine(double sMin, double sMax, double tMin, double tMax, double *line)
{
	double lo = MAX(sMin, tMin), hi = MIN(sMax, tMax);
	if (hi - lo < DKLeastShared) {
		return NO;
	}
	double inset = MIN(8.0, (hi - lo) / 2);
	double sMid = (sMin + sMax) / 2, tMid = (tMin + tMax) / 2;
	if (sMid >= lo + inset && sMid <= hi - inset) {
		*line = sMid;
	} else if (tMid >= lo + inset && tMid <= hi - inset) {
		*line = tMid;
	} else {
		*line = (lo + hi) / 2;
	}
	return YES;
}

@implementation DKOrthogonalRouter

+ (NSArray<NSValue *> *)routeFrom:(NSRect)source to:(NSRect)target avoiding:(NSArray<NSValue *> *)obstacles
{
	return [self routeFrom:source sides:DKRouteSidesAny to:target sides:DKRouteSidesAny avoiding:obstacles];
}

+ (NSArray<NSValue *> *)routeFrom:(NSRect)s
                            sides:(DKRouteSides)sourceSides
                               to:(NSRect)t
                            sides:(DKRouteSides)targetSides
                         avoiding:(NSArray<NSValue *> *)obstacles
{
	if ((sourceSides & DKRouteSidesAny) == 0) {
		sourceSides = DKRouteSidesAny;
	}
	if ((targetSides & DKRouteSidesAny) == 0) {
		targetSides = DKRouteSidesAny;
	}
	obstacles = obstacles ?: @[];
	NSArray *xLanes = DKLanes(s, t, obstacles, YES), *yLanes = DKLanes(s, t, obstacles, NO);
	DKBest best;
	memset(&best, 0, sizeof best);
	for (NSUInteger a = 0; a < 4; a++) {
		DKRouteSides sSide = DKSideOrder[a];
		if ((sourceSides & sSide) == 0) {
			continue;
		}
		for (NSUInteger b = 0; b < 4; b++) {
			DKRouteSides tSide = DKSideOrder[b];
			if ((targetSides & tSide) == 0) {
				continue;
			}
			NSPoint dS = DKSideNormal(sSide), dT = DKSideNormal(tSide);
			NSPoint into = NSMakePoint(-dT.x, -dT.y);
			/* The sides' middles; and, for sides facing across, a line both
			 * share. */
			NSPoint ports[4] = { DKSideMiddle(s, sSide), DKSideMiddle(t, tSide) };
			NSUInteger portPairs = 1;
			double line = 0;
			if (dS.x != 0 && dS.x == -dT.x && DKSharedLine(NSMinY(s), NSMaxY(s), NSMinY(t), NSMaxY(t), &line)) {
				ports[2] = NSMakePoint(ports[0].x, line);
				ports[3] = NSMakePoint(ports[1].x, line);
				portPairs = 2;
			} else if (dS.y != 0 && dS.y == -dT.y && DKSharedLine(NSMinX(s), NSMaxX(s), NSMinX(t), NSMaxX(t), &line)) {
				ports[2] = NSMakePoint(line, ports[0].y);
				ports[3] = NSMakePoint(line, ports[1].y);
				portPairs = 2;
			}
			/* Out of the sides a stub's length before turning; or, where the
			 * shapes are nearer than two stubs, at once. */
			for (NSUInteger variant = 0; variant < portPairs * 2; variant++) {
				NSUInteger pair = variant / 2;
				double stub = variant % 2 == 0 ? DKStub : 0;
				NSPoint P = ports[pair * 2], Q = ports[pair * 2 + 1];
				NSPoint A = NSMakePoint(P.x + dS.x * stub, P.y + dS.y * stub);
				NSPoint B = NSMakePoint(Q.x + dT.x * stub, Q.y + dT.y * stub);
				NSPoint route[8];
				/* Straight, when the stubs line up. */
				if (fabs(A.x - B.x) < 0.01 || fabs(A.y - B.y) < 0.01) {
					NSPoint direct[4] = { P, A, B, Q };
					memcpy(route, direct, sizeof direct);
					DKConsider(&best, route, 4, s, dS, t, into, obstacles);
				}
				/* One bend between the stubs, either way round. */
				NSPoint corners[2] = { NSMakePoint(A.x, B.y), NSMakePoint(B.x, A.y) };
				for (NSUInteger c = 0; c < 2; c++) {
					NSPoint bent[5] = { P, A, corners[c], B, Q };
					memcpy(route, bent, sizeof bent);
					DKConsider(&best, route, 5, s, dS, t, into, obstacles);
				}
				/* Through a lane: a dogleg, or a detour round what is in the way. */
				for (NSNumber *lane in xLanes) {
					double x = [lane doubleValue];
					NSPoint through[6] = { P, A, NSMakePoint(x, A.y), NSMakePoint(x, B.y), B, Q };
					memcpy(route, through, sizeof through);
					DKConsider(&best, route, 6, s, dS, t, into, obstacles);
				}
				for (NSNumber *lane in yLanes) {
					double y = [lane doubleValue];
					NSPoint through[6] = { P, A, NSMakePoint(A.x, y), NSMakePoint(B.x, y), B, Q };
					memcpy(route, through, sizeof through);
					DKConsider(&best, route, 6, s, dS, t, into, obstacles);
				}
			}
		}
	}
	if (!best.found) {
		/* The shapes overlap, or no side allowed leads out: the nearest
		 * edge points, at a right angle. */
		NSPoint from = DKSideMiddle(s, DKRouteSideRight), to = DKSideMiddle(t, DKRouteSideLeft);
		return @[ [NSValue valueWithPoint:from], [NSValue valueWithPoint:NSMakePoint(to.x, from.y)],
			[NSValue valueWithPoint:to] ];
	}
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:best.count];
	for (NSUInteger i = 0; i < best.count; i++) {
		[result addObject:[NSValue valueWithPoint:best.points[i]]];
	}
	return result;
}

+ (NSUInteger)crossingsOfRoute:(NSArray<NSValue *> *)route obstacles:(NSArray<NSValue *> *)obstacles
{
	NSUInteger count = [route count];
	NSPoint *p = malloc(MAX((NSUInteger)1, count) * sizeof(NSPoint));
	for (NSUInteger i = 0; i < count; i++) {
		p[i] = [[route objectAtIndex:i] pointValue];
	}
	NSUInteger crossings = DKCrossings(p, count, obstacles);
	free(p);
	return crossings;
}

#pragma mark A route kept

/* The two points are level (a segment straight across) or one above the
 * other (straight up and down). */
static BOOL
DKLevel(NSPoint a, NSPoint b)
{
	return fabs(a.y - b.y) < 0.5;
}

static BOOL
DKPlumb(NSPoint a, NSPoint b)
{
	return fabs(a.x - b.x) < 0.5;
}

/* The bend next to an end that moved, slid to keep their segment as it
 * was: level stays level, plumb stays plumb. */
static NSPoint
DKFollow(NSPoint bend, NSPoint oldEnd, NSPoint newEnd)
{
	if (DKLevel(oldEnd, bend)) {
		bend.y = newEnd.y;
	} else if (DKPlumb(oldEnd, bend)) {
		bend.x = newEnd.x;
	}
	return bend;
}

+ (NSArray<NSValue *> *)keptRoute:(NSArray<NSValue *> *)points
                           source:(NSRect)source
                           target:(NSRect)target
                      sourceMoved:(NSSize)sourceMoved
                      targetMoved:(NSSize)targetMoved
{
	NSUInteger count = [points count];
	if (count < 3) {
		return nil;
	}
	NSPoint *p = malloc(count * sizeof(NSPoint)), *q = malloc(count * sizeof(NSPoint));
	for (NSUInteger i = 0; i < count; i++) {
		p[i] = [[points objectAtIndex:i] pointValue];
	}
	memcpy(q, p, count * sizeof(NSPoint));
	NSUInteger last = count - 1;
	if (sourceMoved.width != 0 || sourceMoved.height != 0) {
		q[0] = NSMakePoint(p[0].x + sourceMoved.width, p[0].y + sourceMoved.height);
		q[1] = DKFollow(q[1], p[0], q[0]);
	}
	if (targetMoved.width != 0 || targetMoved.height != 0) {
		q[last] = NSMakePoint(p[last].x + targetMoved.width, p[last].y + targetMoved.height);
		q[last - 1] = DKFollow(q[last - 1], p[last], q[last]);
	}
	NSArray *kept = nil;
	BOOL straight = YES;
	/* Every segment straight before is straight still... */
	for (NSUInteger i = 1; i < count && straight; i++) {
		BOOL wasStraight = DKLevel(p[i - 1], p[i]) || DKPlumb(p[i - 1], p[i]);
		if (wasStraight && !DKLevel(q[i - 1], q[i]) && !DKPlumb(q[i - 1], q[i])) {
			straight = NO;
		}
	}
	/* ...and the route leaves and enters its shapes from outside them. */
	if (straight && !NSPointInRect(q[1], NSInsetRect(source, 1, 1)) && !NSPointInRect(q[last - 1], NSInsetRect(target, 1, 1))) {
		NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
		for (NSUInteger i = 0; i < count; i++) {
			[result addObject:[NSValue valueWithPoint:q[i]]];
		}
		kept = result;
	}
	free(p);
	free(q);
	return kept;
}

@end
