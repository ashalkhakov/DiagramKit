/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKExampleDiagram.h
 *
 * A client of DiagramKit, for the tests: an entity-relationship diagram of
 * a small shop's schema, as UDCode's SQL extension draws one. Its tables
 * are laid out in layers (DKLayeredLayout), its foreign keys routed at
 * right angles (DKOrthogonalRouter) and ended in crow's feet; it is a
 * canvas's data source, and draws onto any surface.
 */

#import <DiagramKit/DiagramKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DKExampleDiagram : NSObject

/// The shop's schema, laid out top to bottom.
+ (instancetype)shop;
/// The tables, in order; each one's frame.
@property (nonatomic, readonly) NSArray<NSString *> *tables;
- (NSRect)frameOfTable:(NSString *)table;
- (void)moveTable:(NSString *)table by:(NSSize)delta;
/// The tables the canvas may not move.
@property (nonatomic, copy) NSSet<NSString *> *locked;
@property (nonatomic, readonly) NSRect bounds;
/// How many times it was drawn, and the state it was last drawn in.
@property (nonatomic) NSUInteger drawCount;
@property (nonatomic, strong, nullable) DKDrawingState *lastState;

- (void)drawOn:(id<DKSurface>)surface state:(DKDrawingState *)state;

@end

NS_ASSUME_NONNULL_END
