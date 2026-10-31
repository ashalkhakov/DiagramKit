/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKSVGSurface.h"

/* "12.5", "3": a coordinate, short. */
static NSString *
DKSVGNumber(double value)
{
	NSString *text = [NSString stringWithFormat:@"%.2f", value];
	while ([text hasSuffix:@"0"]) {
		text = [text substringToIndex:[text length] - 1];
	}
	if ([text hasSuffix:@"."]) {
		text = [text substringToIndex:[text length] - 1];
	}
	return [text isEqualToString:@"-0"] ? @"0" : text;
}

static NSString *
DKSVGEscape(NSString *text)
{
	NSString *escaped = [text ?: @"" stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	return [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}

/* The SVG paint for a colour: its hex, and its opacity when not opaque. */
static NSString *
DKSVGPaint(NSString *attribute, DKColor color)
{
	if (color.a >= 0.999) {
		return [NSString stringWithFormat:@"%@=\"%@\"", attribute, DKColorHex(color)];
	}
	return [NSString stringWithFormat:@"%@=\"%@\" %@-opacity=\"%@\"", attribute, DKColorHex(color), attribute,
	                                  DKSVGNumber(color.a)];
}

/* A sans serif's advance for the character, in ems: what a Tahoma-like
 * face gives, near enough to lay out labels. */
static double
DKSVGAdvance(unichar c)
{
	if (c == ' ') {
		return 0.31;
	}
	if ([@"iljtfrI.,:;!|'()[]" rangeOfString:[NSString stringWithCharacters:&c length:1]].location != NSNotFound) {
		return 0.30;
	}
	if ([@"mwMW@%" rangeOfString:[NSString stringWithCharacters:&c length:1]].location != NSNotFound) {
		return 0.85;
	}
	if (c >= 'A' && c <= 'Z') {
		return 0.64;
	}
	return 0.54;
}

@implementation DKSVGSurface
{
	NSRect _bounds;
	NSMutableString *_body;
}

- (instancetype)initWithBounds:(NSRect)bounds
{
	if ((self = [super init])) {
		_bounds = bounds;
		_body = [NSMutableString string];
		_background = DKColorMake(1, 1, 1, 0);
	}
	return self;
}

- (instancetype)initWithSize:(NSSize)size
{
	return [self initWithBounds:NSMakeRect(0, 0, size.width, size.height)];
}

- (instancetype)init
{
	return [self initWithSize:NSZeroSize];
}

- (NSString *)family:(DKFont *)font
{
	NSString *fallback = @"Tahoma, Verdana, 'DejaVu Sans', 'Helvetica Neue', Arial, sans-serif";
	if ([font.name length] == 0) {
		return fallback;
	}
	return [NSString stringWithFormat:@"'%@', %@", font.name, fallback];
}

- (NSSize)sizeOfText:(NSString *)text font:(DKFont *)font
{
	double width = 0;
	for (NSUInteger i = 0; i < [text length]; i++) {
		width += DKSVGAdvance([text characterAtIndex:i]);
	}
	return NSMakeSize(width * font.size * (font.bold ? 1.08 : 1.0), font.size * 1.21);
}

- (NSString *)shapeOf:(DKPath *)path
{
	NSRect rect = path.shapeRect;
	switch (path.shape) {
	case DKPathShapeOval:
		return [NSString stringWithFormat:@"<ellipse cx=\"%@\" cy=\"%@\" rx=\"%@\" ry=\"%@\"", DKSVGNumber(NSMidX(rect)),
		                                  DKSVGNumber(NSMidY(rect)), DKSVGNumber(NSWidth(rect) / 2),
		                                  DKSVGNumber(NSHeight(rect) / 2)];
	case DKPathShapeRect:
	case DKPathShapeRoundedRect: {
		NSMutableString *shape = [NSMutableString stringWithFormat:@"<rect x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\"",
		                                                           DKSVGNumber(NSMinX(rect)), DKSVGNumber(NSMinY(rect)),
		                                                           DKSVGNumber(NSWidth(rect)),
		                                                           DKSVGNumber(NSHeight(rect))];
		if (path.radius > 0) {
			[shape appendFormat:@" rx=\"%@\"", DKSVGNumber(path.radius)];
		}
		return shape;
	}
	case DKPathShapeNone:
		break;
	}
	NSMutableString *data = [NSMutableString string];
	NSPoint p[3];
	for (NSUInteger i = 0; i < path.elementCount; i++) {
		NSString *space = [data length] > 0 ? @" " : @"";
		switch ([path elementAtIndex:i points:p]) {
		case DKPathMoveTo:
			[data appendFormat:@"%@M%@ %@", space, DKSVGNumber(p[0].x), DKSVGNumber(p[0].y)];
			break;
		case DKPathLineTo:
			[data appendFormat:@"%@L%@ %@", space, DKSVGNumber(p[0].x), DKSVGNumber(p[0].y)];
			break;
		case DKPathCurveTo:
			[data appendFormat:@"%@C%@ %@ %@ %@ %@ %@", space, DKSVGNumber(p[0].x), DKSVGNumber(p[0].y),
			                   DKSVGNumber(p[1].x), DKSVGNumber(p[1].y), DKSVGNumber(p[2].x), DKSVGNumber(p[2].y)];
			break;
		case DKPathClose:
			[data appendFormat:@"%@Z", space];
			break;
		}
	}
	return [NSString stringWithFormat:@"<path d=\"%@\"", data];
}

- (void)strokePath:(DKPath *)path color:(DKColor)color width:(double)width dashed:(BOOL)dashed
{
	if (path.empty) {
		return;
	}
	NSString *dash = @"";
	if (dashed) {
		NSString *length = DKSVGNumber(DKDashLength(width));
		dash = [NSString stringWithFormat:@" stroke-dasharray=\"%@ %@\"", length, length];
	}
	[_body appendFormat:@"%@ fill=\"none\" %@ stroke-width=\"%@\"%@/>\n", [self shapeOf:path], DKSVGPaint(@"stroke", color),
	                    DKSVGNumber(width), dash];
}

- (void)fillPath:(DKPath *)path color:(DKColor)color
{
	if (path.empty) {
		return;
	}
	[_body appendFormat:@"%@ %@/>\n", [self shapeOf:path], DKSVGPaint(@"fill", color)];
}

- (void)line:(NSString *)text at:(NSPoint)point font:(DKFont *)font color:(DKColor)color centered:(BOOL)centered
{
	if ([text length] == 0) {
		return;
	}
	/* The baseline an em below the top, as AppKit's fonts sit. */
	[_body appendFormat:@"<text x=\"%@\" y=\"%@\" font-family=\"%@\" font-size=\"%@\"%@%@ %@ xml:space=\"preserve\">%@</text>\n",
	                    DKSVGNumber(point.x), DKSVGNumber(point.y + font.size), DKSVGEscape([self family:font]),
	                    DKSVGNumber(font.size), font.bold ? @" font-weight=\"bold\"" : @"",
	                    centered ? @" text-anchor=\"middle\"" : @"", DKSVGPaint(@"fill", color), DKSVGEscape(text)];
}

- (void)drawText:(NSString *)text at:(NSPoint)point font:(DKFont *)font color:(DKColor)color centered:(BOOL)centered
{
	[self line:text at:point font:font color:color centered:centered];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect font:(DKFont *)font color:(DKColor)color
{
	/* Wrapped at words to the width, line by line. */
	double y = NSMinY(rect);
	double height = font.size * 1.21;
	for (NSString *paragraph in [text ?: @"" componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		NSMutableString *line = [NSMutableString string];
		for (NSString *word in [paragraph componentsSeparatedByString:@" "]) {
			NSString *longer = [line length] > 0 ? [NSString stringWithFormat:@"%@ %@", line, word] : word;
			if ([line length] > 0 && [self sizeOfText:longer font:font].width > NSWidth(rect)) {
				if (y + height > NSMaxY(rect) + 0.5) {
					return;
				}
				[self line:line at:NSMakePoint(NSMinX(rect), y) font:font color:color centered:NO];
				y += height;
				[line setString:word];
			} else {
				[line setString:longer];
			}
		}
		if (y + height > NSMaxY(rect) + 0.5) {
			return;
		}
		[self line:line at:NSMakePoint(NSMinX(rect), y) font:font color:color centered:NO];
		y += height;
	}
}

- (NSString *)SVGString
{
	NSRect bounds = _bounds;
	NSMutableString *svg = [NSMutableString string];
	[svg appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
	[svg appendFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" width=\"%@pt\" height=\"%@pt\" "
	                  @"viewBox=\"%@ %@ %@ %@\">\n",
	                  DKSVGNumber(NSWidth(bounds)), DKSVGNumber(NSHeight(bounds)), DKSVGNumber(NSMinX(bounds)),
	                  DKSVGNumber(NSMinY(bounds)), DKSVGNumber(NSWidth(bounds)), DKSVGNumber(NSHeight(bounds))];
	if ([_title length] > 0) {
		[svg appendFormat:@"<title>%@</title>\n", DKSVGEscape(_title)];
	}
	if (_background.a > 0) {
		[svg appendFormat:@"<rect x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\" %@/>\n", DKSVGNumber(NSMinX(bounds)),
		                  DKSVGNumber(NSMinY(bounds)), DKSVGNumber(NSWidth(bounds)), DKSVGNumber(NSHeight(bounds)),
		                  DKSVGPaint(@"fill", _background)];
	}
	[svg appendString:_body];
	[svg appendString:@"</svg>\n"];
	return svg;
}

@end
