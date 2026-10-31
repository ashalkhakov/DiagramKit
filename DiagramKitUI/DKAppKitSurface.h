/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKAppKitSurface.h
 *
 * A surface that draws into the current AppKit graphics context: paths as
 * NSBezierPaths (rectangles, rounded rectangles and ovals natively), text
 * in NSFonts, measured as AppKit sets it. The context is a flipped view's
 * (a DKCanvasView's), its coordinates the diagram's points.
 */

#import <AppKit/AppKit.h>
#import <DiagramKit/DiagramKit.h>

/* DiagramKitUI's own: exported where it is built for Windows (its
   GNUmakefile), imported everywhere else, as FOUNDATION_EXPORT. */
#ifndef DIAGRAMKITUI_EXPORT
#define DIAGRAMKITUI_EXPORT FOUNDATION_EXPORT
#endif

NS_ASSUME_NONNULL_BEGIN

@interface DKAppKitSurface : NSObject <DKSurface>
+ (instancetype)surface;
@end

/// AppKit's own of a colour, a font (the system font for a font with no
/// name, or one AppKit has not), and a path.
DIAGRAMKITUI_EXPORT NSColor *DKNSColor(DKColor color);
DIAGRAMKITUI_EXPORT NSFont *DKNSFont(DKFont *font);
DIAGRAMKITUI_EXPORT NSBezierPath *DKBezierPath(DKPath *path);

NS_ASSUME_NONNULL_END
