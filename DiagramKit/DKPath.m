/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKPath.h"

/* A quarter ellipse as one cubic: the control points this far along the
 * tangents, of the radius. */
static const double DKKappa = 0.5522847498;

typedef struct {
	DKPathElement kind;
	NSPoint points[3];
} DKPathItem;

@implementation DKPath
{
	DKPathItem *_items;
	NSUInteger _count;
	NSUInteger _capacity;
}

+ (instancetype)path
{
	return [[self alloc] init];
}

- (void)dealloc
{
	free(_items);
}

- (id)copyWithZone:(NSZone *)zone
{
	DKPath *copy = [[[self class] allocWithZone:zone] init];
	[copy appendPath:self];
	copy->_shape = _shape;
	copy->_shapeRect = _shapeRect;
	copy->_radius = _radius;
	return copy;
}

- (void)add:(DKPathElement)kind points:(const NSPoint *)points count:(NSUInteger)count
{
	if (_count == _capacity) {
		_capacity = _capacity > 0 ? _capacity * 2 : 8;
		_items = realloc(_items, _capacity * sizeof(DKPathItem));
	}
	DKPathItem item;
	memset(&item, 0, sizeof item);
	item.kind = kind;
	for (NSUInteger i = 0; i < count; i++) {
		item.points[i] = points[i];
	}
	_items[_count++] = item;
}

/* Changed by hand: no longer the shape it was made as. */
- (void)plain
{
	_shape = DKPathShapeNone;
	_shapeRect = NSZeroRect;
	_radius = 0;
}

- (void)moveTo:(NSPoint)point
{
	[self plain];
	[self add:DKPathMoveTo points:&point count:1];
}

- (void)lineTo:(NSPoint)point
{
	[self plain];
	[self add:DKPathLineTo points:&point count:1];
}

- (void)curveTo:(NSPoint)point control1:(NSPoint)control1 control2:(NSPoint)control2
{
	[self plain];
	NSPoint points[3] = { control1, control2, point };
	[self add:DKPathCurveTo points:points count:3];
}

- (void)close
{
	[self plain];
	[self add:DKPathClose points:NULL count:0];
}

- (void)appendPath:(DKPath *)path
{
	[self plain];
	for (NSUInteger i = 0; i < path->_count; i++) {
		DKPathItem item = path->_items[i];
		[self add:item.kind points:item.points count:3];
	}
}

- (NSUInteger)elementCount
{
	return _count;
}

- (DKPathElement)elementAtIndex:(NSUInteger)index points:(NSPoint *)points
{
	if (index >= _count) {
		[NSException raise:NSRangeException format:@"DKPath: element %lu of %lu", (unsigned long)index,
		                                           (unsigned long)_count];
	}
	DKPathItem item = _items[index];
	if (points != NULL) {
		NSUInteger n = item.kind == DKPathCurveTo ? 3 : item.kind == DKPathClose ? 0 : 1;
		for (NSUInteger i = 0; i < n; i++) {
			points[i] = item.points[i];
		}
	}
	return item.kind;
}

- (BOOL)isEmpty
{
	return _count == 0;
}

- (NSRect)bounds
{
	BOOL any = NO;
	double minX = 0, minY = 0, maxX = 0, maxY = 0;
	for (NSUInteger i = 0; i < _count; i++) {
		DKPathItem item = _items[i];
		NSUInteger n = item.kind == DKPathCurveTo ? 3 : item.kind == DKPathClose ? 0 : 1;
		for (NSUInteger k = 0; k < n; k++) {
			NSPoint p = item.points[k];
			if (!any) {
				minX = maxX = p.x;
				minY = maxY = p.y;
				any = YES;
			} else {
				minX = MIN(minX, p.x);
				maxX = MAX(maxX, p.x);
				minY = MIN(minY, p.y);
				maxY = MAX(maxY, p.y);
			}
		}
	}
	return any ? NSMakeRect(minX, minY, maxX - minX, maxY - minY) : NSZeroRect;
}

#pragma mark Shapes

+ (instancetype)pathWithRect:(NSRect)rect
{
	DKPath *path = [self path];
	[path moveTo:NSMakePoint(NSMinX(rect), NSMinY(rect))];
	[path lineTo:NSMakePoint(NSMaxX(rect), NSMinY(rect))];
	[path lineTo:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
	[path lineTo:NSMakePoint(NSMinX(rect), NSMaxY(rect))];
	[path close];
	path->_shape = DKPathShapeRect;
	path->_shapeRect = rect;
	return path;
}

+ (instancetype)pathWithRoundedRect:(NSRect)rect radius:(double)radius
{
	double r = MAX(0.0, MIN(radius, MIN(NSWidth(rect), NSHeight(rect)) / 2));
	if (r <= 0) {
		return [self pathWithRect:rect];
	}
	double minX = NSMinX(rect), minY = NSMinY(rect), maxX = NSMaxX(rect), maxY = NSMaxY(rect);
	double k = r * (1 - DKKappa);
	DKPath *path = [self path];
	[path moveTo:NSMakePoint(minX + r, minY)];
	[path lineTo:NSMakePoint(maxX - r, minY)];
	[path curveTo:NSMakePoint(maxX, minY + r) control1:NSMakePoint(maxX - k, minY) control2:NSMakePoint(maxX, minY + k)];
	[path lineTo:NSMakePoint(maxX, maxY - r)];
	[path curveTo:NSMakePoint(maxX - r, maxY) control1:NSMakePoint(maxX, maxY - k) control2:NSMakePoint(maxX - k, maxY)];
	[path lineTo:NSMakePoint(minX + r, maxY)];
	[path curveTo:NSMakePoint(minX, maxY - r) control1:NSMakePoint(minX + k, maxY) control2:NSMakePoint(minX, maxY - k)];
	[path lineTo:NSMakePoint(minX, minY + r)];
	[path curveTo:NSMakePoint(minX + r, minY) control1:NSMakePoint(minX, minY + k) control2:NSMakePoint(minX + k, minY)];
	[path close];
	path->_shape = DKPathShapeRoundedRect;
	path->_shapeRect = rect;
	path->_radius = r;
	return path;
}

+ (instancetype)pathWithOvalInRect:(NSRect)rect
{
	double cx = NSMidX(rect), cy = NSMidY(rect);
	double rx = NSWidth(rect) / 2, ry = NSHeight(rect) / 2;
	double kx = rx * DKKappa, ky = ry * DKKappa;
	DKPath *path = [self path];
	[path moveTo:NSMakePoint(cx + rx, cy)];
	[path curveTo:NSMakePoint(cx, cy + ry) control1:NSMakePoint(cx + rx, cy + ky) control2:NSMakePoint(cx + kx, cy + ry)];
	[path curveTo:NSMakePoint(cx - rx, cy) control1:NSMakePoint(cx - kx, cy + ry) control2:NSMakePoint(cx - rx, cy + ky)];
	[path curveTo:NSMakePoint(cx, cy - ry) control1:NSMakePoint(cx - rx, cy - ky) control2:NSMakePoint(cx - kx, cy - ry)];
	[path curveTo:NSMakePoint(cx + rx, cy) control1:NSMakePoint(cx + kx, cy - ry) control2:NSMakePoint(cx + rx, cy - ky)];
	[path close];
	path->_shape = DKPathShapeOval;
	path->_shapeRect = rect;
	return path;
}

+ (instancetype)pathWithPoints:(NSArray<NSValue *> *)points
{
	DKPath *path = [self path];
	for (NSUInteger i = 0; i < [points count]; i++) {
		NSPoint point = [[points objectAtIndex:i] pointValue];
		if (i == 0) {
			[path moveTo:point];
		} else {
			[path lineTo:point];
		}
	}
	return path;
}

+ (instancetype)pathWithLineFrom:(NSPoint)from to:(NSPoint)to
{
	DKPath *path = [self path];
	[path moveTo:from];
	[path lineTo:to];
	return path;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<DKPath %lu elements, shape %ld, bounds %@>", (unsigned long)_count,
	                                  (long)_shape, NSStringFromRect([self bounds])];
}

@end
