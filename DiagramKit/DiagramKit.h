/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DiagramKit.h
 *
 * DiagramKit: the machinery diagram editors share, Foundation only. A
 * client keeps its notation and its model, and draws them through a
 * surface (DKSurface: SVG here, AppKit in DiagramKitUI); DiagramKit has
 * paths, colours and fonts to draw with, the ends of edges (arrows, UML,
 * crow's feet), the geometry of hit testing and placement, layered and
 * force-directed layouts, and orthogonal routing.
 */

#import <Foundation/Foundation.h>

#import <DiagramKit/DKColor.h>
#import <DiagramKit/DKFont.h>
#import <DiagramKit/DKPath.h>
#import <DiagramKit/DKSurface.h>
#import <DiagramKit/DKSVGSurface.h>
#import <DiagramKit/DKGeometry.h>
#import <DiagramKit/DKEdgeEnd.h>
#import <DiagramKit/DKDrawingState.h>
#import <DiagramKit/DKLayeredLayout.h>
#import <DiagramKit/DKForceLayout.h>
#import <DiagramKit/DKOrthogonalRouter.h>
