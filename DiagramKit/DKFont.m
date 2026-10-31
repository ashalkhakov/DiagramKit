/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
#import "DKFont.h"

@implementation DKFont

+ (instancetype)fontWithName:(NSString *)name size:(double)size bold:(BOOL)bold
{
	DKFont *font = [[self alloc] init];
	font->_name = [name length] > 0 ? [name copy] : nil;
	font->_size = size;
	font->_bold = bold;
	return font;
}

+ (instancetype)systemFontOfSize:(double)size bold:(BOOL)bold
{
	return [self fontWithName:nil size:size bold:bold];
}

- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
	return self;
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[DKFont class]]) {
		return NO;
	}
	DKFont *other = object;
	return other.size == _size && other.bold == _bold && (other.name == _name || [other.name isEqualToString:_name]);
}

- (NSUInteger)hash
{
	return [_name hash] ^ (NSUInteger)(_size * 16) ^ (_bold ? 1 : 0);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<DKFont %@ %g%@>", _name ?: @"system", _size, _bold ? @" bold" : @""];
}

@end
