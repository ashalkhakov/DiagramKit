/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKColor.h"
#include <math.h>

DKColor
DKColorMake(double r, double g, double b, double a)
{
	DKColor color = { r, g, b, a };
	return color;
}

DKColor
DKColorWithAlpha(DKColor color, double alpha)
{
	color.a = alpha;
	return color;
}

static int
DKByte(double component)
{
	return (int)lround(MIN(MAX(component, 0.0), 1.0) * 255);
}

NSString *
DKColorHex(DKColor color)
{
	return [NSString stringWithFormat:@"#%02x%02x%02x", DKByte(color.r), DKByte(color.g), DKByte(color.b)];
}

BOOL
DKColorEqual(DKColor a, DKColor b)
{
	return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
}

DKColor
DKColorBlack(void)
{
	return DKColorMake(0, 0, 0, 1);
}

DKColor
DKColorWhite(void)
{
	return DKColorMake(1, 1, 1, 1);
}

DKColor
DKColorSelection(void)
{
	return DKColorMake(0.10, 0.45, 0.95, 1);
}
