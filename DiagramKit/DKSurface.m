/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKSurface.h"

double
DKDashLength(double width)
{
	return MAX(2.0, 2.0 * width);
}

NSUInteger
DKStrokePattern(DKStrokeStyle style, double width, double pattern[2])
{
	switch (style) {
	case DKStrokeDashed:
		pattern[0] = pattern[1] = DKDashLength(width);
		return 2;
	case DKStrokeDotted:
		pattern[0] = 1.5 * MAX(1.0, width);
		pattern[1] = 3.0 * MAX(1.0, width);
		return 2;
	default:
		return 0;
	}
}
