/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKColor.h
 *
 * The colours a diagram is drawn in, as plain values: Foundation has no
 * NSColor, and a surface (DKSurface) turns them into its own. A colour is
 * its RGB components and alpha, 0 to 1.
 */

#import <Foundation/Foundation.h>

/* DiagramKit's own: exported where it is built for Windows (its
   GNUmakefile), imported everywhere else, as FOUNDATION_EXPORT. */
#ifndef DIAGRAMKIT_EXPORT
#define DIAGRAMKIT_EXPORT FOUNDATION_EXPORT
#endif

NS_ASSUME_NONNULL_BEGIN

typedef struct {
	double r, g, b, a;
} DKColor;

DIAGRAMKIT_EXPORT DKColor DKColorMake(double r, double g, double b, double a);
/// The colour with another alpha.
DIAGRAMKIT_EXPORT DKColor DKColorWithAlpha(DKColor color, double alpha);
/// "#800080": the RGB part, for SVG and the like.
DIAGRAMKIT_EXPORT NSString *DKColorHex(DKColor color);
DIAGRAMKIT_EXPORT BOOL DKColorEqual(DKColor a, DKColor b);

/// Black and white, and the colour gestures and selections are drawn in
/// (a blue that reads on light and dark paper).
DIAGRAMKIT_EXPORT DKColor DKColorBlack(void);
DIAGRAMKIT_EXPORT DKColor DKColorWhite(void);
DIAGRAMKIT_EXPORT DKColor DKColorSelection(void);

NS_ASSUME_NONNULL_END
