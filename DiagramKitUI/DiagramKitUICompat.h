/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DiagramKitUICompat.h
 *
 * Included on GNUstep only (the GNUmakefiles' -include), never by Xcode:
 * AppKit names gnustep-gui lacks, defined by the ones it has, so the
 * sources can use current AppKit. Only names; behaviour belongs in
 * gnustep-gui.
 */
#ifdef __OBJC__
#import <AppKit/AppKit.h>

#ifndef NSCompositingOperationSourceOver
#define NSCompositingOperationSourceOver NSCompositeSourceOver
#endif
#ifndef NSBitmapImageFileTypePNG
#define NSBitmapImageFileTypePNG NSPNGFileType
#endif
#ifndef NSEventModifierFlagShift
#define NSEventModifierFlagShift NSShiftKeyMask
#define NSEventModifierFlagOption NSAlternateKeyMask
#define NSEventModifierFlagCommand NSCommandKeyMask
#define NSEventModifierFlagControl NSControlKeyMask
#endif
#ifndef NSTextAlignmentCenter
#define NSTextAlignmentCenter NSCenterTextAlignment
#define NSTextAlignmentLeft NSLeftTextAlignment
#define NSTextAlignmentRight NSRightTextAlignment
#endif
#endif
