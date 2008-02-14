//
//  MainController.h
//  Edger
//
//  Created by Kent Sutherland on 11/1/07.
//  Copyright 2007-2008 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "WarpRange.h"

typedef struct {
	CGFloat point;
	WarpRange range;
	BOOL isLeftOrTop;
	BOOL isDockOrMenubar;
	NSScreen *screen;
	void *next;
} Edge;

enum {
	LeftDirection = 0,
	RightDirection,
	UpDirection,
	DownDirection
};

@class WarpEdgeWindow;

@interface MainController : NSObject {
	EventHandlerRef mouseHandler;
}

+ (NSInteger)numberOfSpacesRows;
+ (NSInteger)numberOfSpacesColumns;
+ (NSInteger)getCurrentSpaceRow:(NSInteger *)row column:(NSInteger *)column;
+ (void)warpInDirection:(NSUInteger)direction;
+ (BOOL)switchToSpaceRow:(NSInteger)row column:(NSInteger)column;

- (void)updateWarpRects;

@end
