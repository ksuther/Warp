/*
 * WarpEdgeWindow.m
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

#import "WarpEdgeWindow.h"
#import "WarpEdgeView.h"

static const CGFloat kWarpEdgeWidth = 240.0f;

@implementation WarpEdgeWindow

@synthesize direction = _direction;

+ (WarpEdgeWindow *)windowWithEdge:(Edge *)edge workspace:(NSInteger)workspace direction:(NSUInteger)direction
{
	return [[[WarpEdgeWindow alloc] initWithEdge:edge workspace:workspace direction:direction] autorelease];
}

+ (NSRect)frameForEdge:(Edge *)edge direction:(NSUInteger)direction
{
	NSRect contentRect;
	NSPoint mouseLoc = [NSEvent mouseLocation];
	NSRect screenFrame = [edge->screen frame];
	CGFloat width = screenFrame.size.width * 0.15f;
	CGFloat height = width * screenFrame.size.height / screenFrame.size.width;
	
	contentRect.size.width = width + 6.0f;
	contentRect.size.height = height + 6.0f;
	
	if (direction == LeftDirection) {
		contentRect.origin.x = edge->point - 15.0f;
		contentRect.origin.y = mouseLoc.y - (height / 2);
		
		contentRect.size.width += 15.0f;
	} else if (direction == RightDirection) {
		contentRect.origin.x = edge->point - width + 1.0f;
		contentRect.origin.y = mouseLoc.y - (height / 2);
		
		contentRect.size.width += 15.0f;
	} else if (direction == UpDirection) {
		contentRect.origin.y = screenFrame.origin.y + screenFrame.size.height - height;
		contentRect.origin.x = mouseLoc.x - (width / 2);
		
		contentRect.size.height += 15.0f;
	} else if (direction == DownDirection) {
		contentRect.origin.y = screenFrame.origin.y - 15.0f;
		contentRect.origin.x = mouseLoc.x - (width / 2);
		
		contentRect.size.height += 15.0f;
	} else {
		return NSZeroRect;
	}
	
	return contentRect;
}

- (id)initWithEdge:(Edge *)edge workspace:(NSInteger)workspace direction:(NSUInteger)direction
{
	NSRect contentRect = [WarpEdgeWindow frameForEdge:edge direction:direction];
	
	if ( (self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES]) ) {
		_edge = *edge;
		_direction = direction;
		
		[self setContentView:[[[WarpEdgeView alloc] initWithFrame:contentRect workspace:workspace direction:direction] autorelease]];
		[self setLevel:NSScreenSaverWindowLevel];
		[self setBackgroundColor:[NSColor clearColor]];
		[self setOpaque:NO];
		[self setAcceptsMouseMovedEvents:YES];
		[self setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	}
	return self;
}

- (Edge *)edge
{
	return &_edge;
}

- (void)setEdge:(Edge *)edge
{
	_edge = *edge;
}

- (BOOL)canBecomeKeyWindow
{
	return NO;
}

- (BOOL)canBecomeMainWindow
{
	return NO;
}

- (void)fadeOut
{
	[(WarpEdgeView *)[self contentView] fadeOut];
}

@end
