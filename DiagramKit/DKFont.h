/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKFont.h
 *
 * A font a diagram's text is set in, as a plain value: Foundation has no
 * NSFont, and a surface (DKSurface) finds its own by the name (nil: its
 * system font), the size in points and the weight.
 */

#import <DiagramKit/DKColor.h>

NS_ASSUME_NONNULL_BEGIN

/// A font: a family by name, or the system's (name nil); a size in points;
/// bold or regular. Immutable.
@interface DKFont : NSObject <NSCopying>
+ (instancetype)fontWithName:(nullable NSString *)name size:(double)size bold:(BOOL)bold;
+ (instancetype)systemFontOfSize:(double)size bold:(BOOL)bold;
/// nil: the system font.
@property (nonatomic, readonly, copy, nullable) NSString *name;
@property (nonatomic, readonly) double size;
@property (nonatomic, readonly) BOOL bold;
@end

NS_ASSUME_NONNULL_END
