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

@class WarpEdgeWindow, PagerController;

@interface MainController : NSObject {
	EventHandlerRef mouseHandler;
	EventHandlerUPP mouseMovedHandlerUPP;
	
	EventHandlerRef hotKeyHandlerRef;
	EventHotKeyRef hotKeyRef;
	
	//The currently active hot key for toggling the pager
	short _activeKeyCode;
	unsigned int _activeModifiers;
	
	PagerController *_pagerController;
}

+ (NSInteger)numberOfSpacesRows;
+ (NSInteger)numberOfSpacesColumns;
+ (NSInteger)getCurrentSpaceRow:(NSInteger *)row column:(NSInteger *)column;
+ (void)warpInDirection:(NSUInteger)direction edge:(Edge *)edge;
+ (BOOL)switchToSpaceRow:(NSInteger)row column:(NSInteger)column;
+ (BOOL)switchToSpaceIndex:(NSInteger)index;
+ (NSInteger)spacesIndexForRow:(NSInteger)row column:(NSInteger)column;

- (void)updateWarpRects;

@end
