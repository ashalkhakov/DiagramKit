/* Copyright (c) 2026 Artyom Shalkhakov. MIT. */
/*
 * DKRecordingSurface.h
 *
 * A surface for the tests: it draws nothing and keeps what it was asked to
 * draw, in order, each a DKRecordedOperation. Text is measured as
 * DKSVGSurface measures it.
 */

#import <DiagramKit/DiagramKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DKRecordedKind) {
	DKRecordedStroke,
	DKRecordedFill,
	DKRecordedText,
};

@interface DKRecordedOperation : NSObject
@property (nonatomic) DKRecordedKind kind;
@property (nonatomic, strong, nullable) DKPath *path;
@property (nonatomic) DKColor color;
@property (nonatomic) double width;
@property (nonatomic) BOOL dashed;
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic) NSRect rect;
@end

@interface DKRecordingSurface : NSObject <DKSurface>
@property (nonatomic, readonly) NSMutableArray<DKRecordedOperation *> *operations;
- (NSArray<DKRecordedOperation *> *)operationsOfKind:(DKRecordedKind)kind;
@end

/// The points of a path's moves and lines, in order.
NSArray<NSValue *> *DKPathPoints(DKPath *path);
/// How many subpaths (moves) the path has.
NSUInteger DKPathMoves(DKPath *path);

NS_ASSUME_NONNULL_END
