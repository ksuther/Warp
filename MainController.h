/*
 * MainController.h
 *
 * Copyright (c) 2007-2011 Kent Sutherland
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
 * Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
/* BKE ADDED START */
#import <ScriptingBridge/ScriptingBridge.h>
/* BKE ADDED END */
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
	
	NSString *_cachedVersion;
}

+ (NSInteger)numberOfSpacesRows;
+ (NSInteger)numberOfSpacesColumns;
+ (NSInteger)getCurrentSpaceIndex;
+ (NSInteger)getCurrentSpaceRow:(NSInteger *)row column:(NSInteger *)column;
+ (void)warpInDirection:(NSUInteger)direction edge:(Edge *)edge;
+ (BOOL)switchToSpaceRow:(NSInteger)row column:(NSInteger)column;
+ (BOOL)switchToSpaceIndex:(NSInteger)index;
+ (NSInteger)spacesIndexForRow:(NSInteger)row column:(NSInteger)column;

/* BKE ADDED START */
// how long we must wait before asking the current space when moving
#define DESKTOP_MOVE_DELAY 0.4f

+ (NSInteger) currentSpaceIdx;
+ (void) setSpaceWithoutTransition:(unsigned int)spaceIndex;
/* BKE ADDED END */

- (void)updateWarpRects;

@end
