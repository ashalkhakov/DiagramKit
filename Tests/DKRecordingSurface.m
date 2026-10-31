/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKRecordingSurface.h"

@implementation DKRecordedOperation
@end

@implementation DKRecordingSurface
{
	DKSVGSurface *_measure;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_operations = [NSMutableArray array];
		_measure = [[DKSVGSurface alloc] initWithSize:NSMakeSize(1, 1)];
	}
	return self;
}

- (NSArray<DKRecordedOperation *> *)operationsOfKind:(DKRecordedKind)kind
{
	NSMutableArray *found = [NSMutableArray array];
	for (DKRecordedOperation *operation in _operations) {
		if (operation.kind == kind) {
			[found addObject:operation];
		}
	}
	return found;
}

- (NSSize)sizeOfText:(NSString *)text font:(DKFont *)font
{
	return [_measure sizeOfText:text font:font];
}

- (NSSize)sizeOfText:(NSString *)text font:(DKFont *)font wrappedToWidth:(double)width
{
	return [_measure sizeOfText:text font:font wrappedToWidth:width];
}

- (void)strokePath:(DKPath *)path color:(DKColor)color width:(double)width style:(DKStrokeStyle)style
{
	DKRecordedOperation *operation = [[DKRecordedOperation alloc] init];
	operation.kind = DKRecordedStroke;
	operation.path = [path copy];
	operation.color = color;
	operation.width = width;
	operation.strokeStyle = style;
	operation.rect = path.bounds;
	[_operations addObject:operation];
}

- (void)fillPath:(DKPath *)path color:(DKColor)color
{
	DKRecordedOperation *operation = [[DKRecordedOperation alloc] init];
	operation.kind = DKRecordedFill;
	operation.path = [path copy];
	operation.color = color;
	operation.rect = path.bounds;
	[_operations addObject:operation];
}

- (void)drawText:(NSString *)text at:(NSPoint)point font:(DKFont *)font color:(DKColor)color centered:(BOOL)centered
{
	DKRecordedOperation *operation = [[DKRecordedOperation alloc] init];
	operation.kind = DKRecordedText;
	operation.text = text;
	operation.color = color;
	operation.rect = NSMakeRect(point.x, point.y, 0, 0);
	[_operations addObject:operation];
}

- (void)drawText:(NSString *)text centeredAt:(NSPoint)point font:(DKFont *)font color:(DKColor)color
        rotation:(DKTextRotation)rotation
{
	DKRecordedOperation *operation = [[DKRecordedOperation alloc] init];
	operation.kind = DKRecordedText;
	operation.text = text;
	operation.color = color;
	operation.rect = NSMakeRect(point.x, point.y, 0, 0);
	operation.centeredAt = YES;
	operation.rotation = rotation;
	[_operations addObject:operation];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect font:(DKFont *)font color:(DKColor)color
{
	DKRecordedOperation *operation = [[DKRecordedOperation alloc] init];
	operation.kind = DKRecordedText;
	operation.text = text;
	operation.color = color;
	operation.rect = rect;
	[_operations addObject:operation];
}

@end

NSArray<NSValue *> *
DKPathPoints(DKPath *path)
{
	NSMutableArray *points = [NSMutableArray array];
	NSPoint p[3];
	for (NSUInteger i = 0; i < path.elementCount; i++) {
		DKPathElement element = [path elementAtIndex:i points:p];
		if (element == DKPathMoveTo || element == DKPathLineTo) {
			[points addObject:[NSValue valueWithPoint:p[0]]];
		} else if (element == DKPathCurveTo) {
			[points addObject:[NSValue valueWithPoint:p[2]]];
		}
	}
	return points;
}

NSUInteger
DKPathMoves(DKPath *path)
{
	NSUInteger moves = 0;
	for (NSUInteger i = 0; i < path.elementCount; i++) {
		if ([path elementAtIndex:i points:NULL] == DKPathMoveTo) {
			moves++;
		}
	}
	return moves;
}
