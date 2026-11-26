/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKSelectors.h
 *
 * Whether two selectors are the same (a command and a @selector()). Not
 * ==: on GNUstep (libobjc2) a selector made from a name (a XIB's action,
 * the key bindings, NSSelectorFromString) and the compiler's @selector()
 * of the same name are different pointers. Not sel_isEqual either: on
 * macOS it is declared in <objc/runtime.h> only. Private to the framework.
 */
#import <Foundation/Foundation.h>
#include <string.h>

static inline BOOL DKSameSelector(SEL a, SEL b) {
	if (a == b) return YES;
	return a && b && strcmp(sel_getName(a), sel_getName(b)) == 0;
}
