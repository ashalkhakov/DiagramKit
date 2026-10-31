/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKGeometry.h"
#include <math.h>

NSPoint
DKEdgePoint(NSRect rect, NSPoint toward)
{
	NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
	double dx = toward.x - center.x;
	double dy = toward.y - center.y;
	if (fabs(dx) < 0.0001 && fabs(dy) < 0.0001) {
		return center;
	}
	double halfWidth = NSWidth(rect) / 2;
	double halfHeight = NSHeight(rect) / 2;
	double scale = 1.0 / MAX(fabs(dx) / MAX(halfWidth, 0.0001), fabs(dy) / MAX(halfHeight, 0.0001));
	return NSMakePoint(center.x + dx * scale, center.y + dy * scale);
}

double
DKDistanceToSegment(NSPoint p, NSPoint a, NSPoint b)
{
	double dx = b.x - a.x, dy = b.y - a.y;
	double lengthSquared = dx * dx + dy * dy;
	if (lengthSquared <= 0) {
		return hypot(p.x - a.x, p.y - a.y);
	}
	double t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared;
	t = MAX(0.0, MIN(1.0, t));
	return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
}

double
DKDistanceToRoute(NSPoint p, NSArray<NSValue *> *route)
{
	NSUInteger count = [route count];
	if (count == 0) {
		return INFINITY;
	}
	if (count == 1) {
		NSPoint only = [[route objectAtIndex:0] pointValue];
		return hypot(p.x - only.x, p.y - only.y);
	}
	double nearest = INFINITY;
	for (NSUInteger i = 1; i < count; i++) {
		nearest = MIN(nearest, DKDistanceToSegment(p, [[route objectAtIndex:i - 1] pointValue],
		                                           [[route objectAtIndex:i] pointValue]));
	}
	return nearest;
}

double
DKRouteLength(NSArray<NSValue *> *route)
{
	double length = 0;
	for (NSUInteger i = 1; i < [route count]; i++) {
		NSPoint a = [[route objectAtIndex:i - 1] pointValue], b = [[route objectAtIndex:i] pointValue];
		length += hypot(b.x - a.x, b.y - a.y);
	}
	return length;
}

NSPoint
DKRouteMidpoint(NSArray<NSValue *> *route)
{
	if ([route count] == 0) {
		return NSZeroPoint;
	}
	double half = DKRouteLength(route) / 2;
	for (NSUInteger i = 1; i < [route count]; i++) {
		NSPoint a = [[route objectAtIndex:i - 1] pointValue], b = [[route objectAtIndex:i] pointValue];
		double length = hypot(b.x - a.x, b.y - a.y);
		if (length >= half && length > 0) {
			double t = half / length;
			return NSMakePoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
		}
		half -= length;
	}
	return [[route lastObject] pointValue];
}

NSRect
DKRouteBounds(NSArray<NSValue *> *route)
{
	if ([route count] == 0) {
		return NSZeroRect;
	}
	NSPoint first = [[route objectAtIndex:0] pointValue];
	double minX = first.x, minY = first.y, maxX = first.x, maxY = first.y;
	for (NSValue *value in route) {
		NSPoint p = [value pointValue];
		minX = MIN(minX, p.x);
		minY = MIN(minY, p.y);
		maxX = MAX(maxX, p.x);
		maxY = MAX(maxY, p.y);
	}
	return NSMakeRect(minX, minY, maxX - minX, maxY - minY);
}

/* Whether the rectangle is clear of the occupied ones by the margin. */
static BOOL
DKIsFree(NSRect rect, NSArray<NSValue *> *occupied, double margin)
{
	NSRect padded = NSInsetRect(rect, -margin, -margin);
	for (NSValue *value in occupied) {
		if (NSIntersectsRect(padded, [value rectValue])) {
			return NO;
		}
	}
	return YES;
}

/* How far apart the rings of the spiral are: ORMKit's, 0.3 inches. */
static const double DKSpiralStep = 0.3 * 72.0;

NSRect
DKFreeSpotNear(NSSize size, NSPoint near, NSArray<NSValue *> *occupied, double margin)
{
	for (NSUInteger ring = 0; ring < 40; ring++) {
		NSUInteger steps = ring == 0 ? 1 : ring * 8;
		for (NSUInteger step = 0; step < steps; step++) {
			double angle = 2 * M_PI * step / steps;
			double radius = ring * DKSpiralStep;
			NSPoint origin = NSMakePoint(round(near.x + radius * cos(angle) - size.width / 2),
			                             round(near.y + radius * sin(angle) - size.height / 2));
			if (origin.x < 0 || origin.y < 0) {
				continue;
			}
			NSRect rect = NSMakeRect(origin.x, origin.y, size.width, size.height);
			if (DKIsFree(rect, occupied, margin)) {
				return rect;
			}
		}
	}
	return NSMakeRect(round(near.x - size.width / 2), round(near.y - size.height / 2), size.width, size.height);
}
