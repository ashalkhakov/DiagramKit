/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKDrawingState.h"

@implementation DKDrawingState

- (instancetype)init
{
	if ((self = [super init])) {
		_selection = [NSSet set];
		_zoom = 1.0;
	}
	return self;
}

- (BOOL)showsSelected:(id)item
{
	return !_forPrinting && item != nil && [_selection containsObject:item];
}

- (BOOL)showsHovered:(id)item
{
	return !_forPrinting && item != nil && [_hoveredItem isEqual:item];
}

@end
