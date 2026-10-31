/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKEdgeEnd.h"
#import "DKGeometry.h"
#include <math.h>

/* An end's frame: its tip, the unit vector back along the line (away from
 * the shape), the normal to it, and the unit sizes are measured in. */
typedef struct {
	NSPoint tip;
	double bx, by;
	double nx, ny;
	double k;
} DKEndFrame;

static DKEndFrame
DKFrameOf(NSPoint tip, NSPoint from, double width)
{
	DKEndFrame f;
	f.tip = tip;
	double dx = from.x - tip.x, dy = from.y - tip.y;
	double length = hypot(dx, dy);
	if (length <= 0) {
		dx = -1;
		dy = 0;
		length = 1;
	}
	f.bx = dx / length;
	f.by = dy / length;
	f.nx = -f.by;
	f.ny = f.bx;
	f.k = MAX(1.0, width);
	return f;
}

/* The point @a back along the line from the tip and @a side across it, in
 * units. */
static NSPoint
DKAt(DKEndFrame f, double back, double side)
{
	return NSMakePoint(f.tip.x + (f.bx * back + f.nx * side) * f.k, f.tip.y + (f.by * back + f.ny * side) * f.k);
}

/* The sizes, in units (a point at widths up to 1). */
static const double DKArrowLength = 8.0, DKArrowAngle = 0.42;
static const double DKTriangleLength = 11.0, DKTriangleAngle = 0.52;
static const double DKDiamondLength = 14.0, DKDiamondHalfWidth = 5.0;
static const double DKFootLength = 10.0, DKFootHalfWidth = 6.0;
static const double DKBarHalfLength = 6.0, DKInnerBar = 8.0, DKMarkGap = 4.0;
static const double DKCircleRadius = 3.5;

static BOOL
DKIsCrowFoot(DKEdgeEnd end)
{
	return end >= DKEdgeEndCrowFootOne && end <= DKEdgeEndCrowFootZeroOrMany;
}

static BOOL
DKHasFoot(DKEdgeEnd end)
{
	return end == DKEdgeEndCrowFootMany || end == DKEdgeEndCrowFootOneOrMany || end == DKEdgeEndCrowFootZeroOrMany;
}

/* How far the inner mark reaches: the foot, or the bar. */
static double
DKInnerExtent(DKEdgeEnd end)
{
	return DKHasFoot(end) ? DKFootLength : DKInnerBar;
}

/* The outer mark: a bar (one) or a circle (zero), when there is one. */
static BOOL
DKHasOuterBar(DKEdgeEnd end)
{
	return end == DKEdgeEndCrowFootOne || end == DKEdgeEndCrowFootOneOrMany;
}

static BOOL
DKHasCircle(DKEdgeEnd end)
{
	return end == DKEdgeEndCrowFootZeroOrOne || end == DKEdgeEndCrowFootZeroOrMany;
}

static double
DKCircleCenter(DKEdgeEnd end)
{
	return DKInnerExtent(end) + DKMarkGap - 1.0 + DKCircleRadius;
}

/* How far from the tip the line stops, in points: at a hollow mark's
 * near edge, or under a filled one. */
static double
DKLineInset(DKEdgeEnd end, double width)
{
	double k = MAX(1.0, width);
	switch (end) {
	case DKEdgeEndArrow:
		return MAX(0.0, DKArrowLength * cos(DKArrowAngle) * k - width);
	case DKEdgeEndTriangle:
		return DKTriangleLength * cos(DKTriangleAngle) * k;
	case DKEdgeEndDiamond:
	case DKEdgeEndFilledDiamond:
		return DKDiamondLength * k;
	default:
		return 0;
	}
}

double
DKEdgeEndLength(DKEdgeEnd end, double width)
{
	double k = MAX(1.0, width);
	switch (end) {
	case DKEdgeEndNone:
		return 0;
	case DKEdgeEndArrow:
	case DKEdgeEndOpenArrow:
		return DKArrowLength * cos(DKArrowAngle) * k;
	case DKEdgeEndTriangle:
		return DKTriangleLength * cos(DKTriangleAngle) * k;
	case DKEdgeEndDiamond:
	case DKEdgeEndFilledDiamond:
		return DKDiamondLength * k;
	case DKEdgeEndCrowFootMany:
		return DKFootLength * k;
	default:
		if (DKHasCircle(end)) {
			return (DKCircleCenter(end) + DKCircleRadius) * k;
		}
		return (DKInnerExtent(end) + DKMarkGap) * k;
	}
}

static void
DKStrokeLine(id<DKSurface> surface, NSPoint a, NSPoint b, DKColor color, double width)
{
	[surface strokePath:[DKPath pathWithLineFrom:a to:b] color:color width:width dashed:NO];
}

static void
DKBar(id<DKSurface> surface, DKEndFrame f, double back, DKColor color, double width)
{
	DKStrokeLine(surface, DKAt(f, back, -DKBarHalfLength), DKAt(f, back, DKBarHalfLength), color, width);
}

void
DKDrawEdgeEnd(id<DKSurface> surface, NSPoint tip, NSPoint from, DKEdgeEnd end, DKColor color, double width)
{
	DKEndFrame f = DKFrameOf(tip, from, width);
	switch (end) {
	case DKEdgeEndNone:
		return;
	case DKEdgeEndArrow:
	case DKEdgeEndOpenArrow: {
		double along = DKArrowLength * cos(DKArrowAngle), across = DKArrowLength * sin(DKArrowAngle);
		DKPath *head = [DKPath path];
		[head moveTo:DKAt(f, along, -across)];
		[head lineTo:tip];
		[head lineTo:DKAt(f, along, across)];
		if (end == DKEdgeEndArrow) {
			[head close];
			[surface fillPath:head color:color];
		} else {
			[surface strokePath:head color:color width:width dashed:NO];
		}
		return;
	}
	case DKEdgeEndTriangle: {
		double along = DKTriangleLength * cos(DKTriangleAngle), across = DKTriangleLength * sin(DKTriangleAngle);
		DKPath *triangle = [DKPath path];
		[triangle moveTo:tip];
		[triangle lineTo:DKAt(f, along, -across)];
		[triangle lineTo:DKAt(f, along, across)];
		[triangle close];
		[surface strokePath:triangle color:color width:width dashed:NO];
		return;
	}
	case DKEdgeEndDiamond:
	case DKEdgeEndFilledDiamond: {
		DKPath *diamond = [DKPath path];
		[diamond moveTo:tip];
		[diamond lineTo:DKAt(f, DKDiamondLength / 2, -DKDiamondHalfWidth)];
		[diamond lineTo:DKAt(f, DKDiamondLength, 0)];
		[diamond lineTo:DKAt(f, DKDiamondLength / 2, DKDiamondHalfWidth)];
		[diamond close];
		if (end == DKEdgeEndFilledDiamond) {
			[surface fillPath:diamond color:color];
		}
		[surface strokePath:diamond color:color width:width dashed:NO];
		return;
	}
	default:
		break;
	}
	if (!DKIsCrowFoot(end)) {
		return;
	}
	/* The inner mark: the foot's three toes on the shape, meeting back
	 * along the line; or a bar. */
	if (DKHasFoot(end)) {
		NSPoint heel = DKAt(f, DKFootLength, 0);
		DKPath *foot = [DKPath path];
		[foot moveTo:DKAt(f, 0, -DKFootHalfWidth)];
		[foot lineTo:heel];
		[foot lineTo:DKAt(f, 0, DKFootHalfWidth)];
		[foot moveTo:heel];
		[foot lineTo:tip];
		[surface strokePath:foot color:color width:width dashed:NO];
	} else {
		DKBar(surface, f, DKInnerBar, color, width);
	}
	/* The outer: a bar, or a circle. */
	if (DKHasOuterBar(end)) {
		DKBar(surface, f, DKInnerExtent(end) + DKMarkGap, color, width);
	} else if (DKHasCircle(end)) {
		NSPoint center = DKAt(f, DKCircleCenter(end), 0);
		double r = DKCircleRadius * f.k;
		[surface strokePath:[DKPath pathWithOvalInRect:NSMakeRect(center.x - r, center.y - r, 2 * r, 2 * r)] color:color
		              width:width
		             dashed:NO];
	}
}

#pragma mark The line

/* The point at a distance along the route, and the segment it is on. */
static NSPoint
DKPointAlong(NSPoint *p, NSUInteger count, double distance, NSUInteger *segment)
{
	for (NSUInteger i = 1; i < count; i++) {
		double length = hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y);
		if (distance <= length || i == count - 1) {
			double t = length > 0 ? MAX(0.0, MIN(1.0, distance / length)) : 0;
			*segment = i;
			return NSMakePoint(p[i - 1].x + (p[i].x - p[i - 1].x) * t, p[i - 1].y + (p[i].y - p[i - 1].y) * t);
		}
		distance -= length;
	}
	*segment = 1;
	return p[0];
}

/* The part of the route from one distance along it to another, onto the
 * path as a subpath of its own. */
static void
DKAppendPiece(DKPath *path, NSPoint *p, NSUInteger count, double from, double to)
{
	if (to - from <= 0.001) {
		return;
	}
	NSUInteger first = 1, last = 1;
	NSPoint start = DKPointAlong(p, count, from, &first);
	NSPoint end = DKPointAlong(p, count, to, &last);
	[path moveTo:start];
	for (NSUInteger i = first; i < last; i++) {
		[path lineTo:p[i]];
	}
	[path lineTo:end];
}

/* The span a crow's foot's circle covers, from the tip, in points. */
static void
DKCircleSpan(DKEdgeEnd end, double width, double *near, double *far)
{
	double k = MAX(1.0, width);
	*near = (DKCircleCenter(end) - DKCircleRadius) * k;
	*far = (DKCircleCenter(end) + DKCircleRadius) * k;
}

void
DKDrawRoute(id<DKSurface> surface, NSArray<NSValue *> *points, DKColor color, double width, BOOL dashed,
            DKEdgeEnd startEnd, DKEdgeEnd endEnd)
{
	/* The distinct points: a repeated one makes no segment to point along. */
	NSUInteger count = 0;
	NSPoint *p = malloc(MAX((NSUInteger)1, [points count]) * sizeof(NSPoint));
	for (NSValue *value in points) {
		NSPoint point = [value pointValue];
		if (count == 0 || hypot(point.x - p[count - 1].x, point.y - p[count - 1].y) > 0.0001) {
			p[count++] = point;
		}
	}
	if (count < 2) {
		free(p);
		return;
	}
	double total = 0;
	for (NSUInteger i = 1; i < count; i++) {
		total += hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y);
	}
	/* The pieces of line: the route less the ends' insets and circles. */
	double from = MIN(DKLineInset(startEnd, width), total);
	double to = MAX(total - DKLineInset(endEnd, width), from);
	double cuts[4];
	NSUInteger cutCount = 0;
	if (DKHasCircle(startEnd)) {
		DKCircleSpan(startEnd, width, &cuts[0], &cuts[1]);
		cutCount = 2;
	}
	DKPath *line = [DKPath path];
	double at = from;
	if (cutCount == 2 && cuts[1] < to) {
		DKAppendPiece(line, p, count, at, MIN(cuts[0], to));
		at = MAX(at, cuts[1]);
	}
	if (DKHasCircle(endEnd)) {
		double near, far;
		DKCircleSpan(endEnd, width, &near, &far);
		if (total - far > at) {
			DKAppendPiece(line, p, count, at, total - far);
			at = MAX(at, total - near);
		}
	}
	DKAppendPiece(line, p, count, at, to);
	if (!line.empty) {
		[surface strokePath:line color:color width:width dashed:dashed];
	}
	DKDrawEdgeEnd(surface, p[0], p[1], startEnd, color, width);
	DKDrawEdgeEnd(surface, p[count - 1], p[count - 2], endEnd, color, width);
	free(p);
}
