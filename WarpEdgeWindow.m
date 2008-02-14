//
//  WarpEdgeWindow.m
//  Warp
//
//  Created by Kent Sutherland on 2/13/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import "WarpEdgeWindow.h"
#import "WarpEdgeView.h"

static const CGFloat kWarpEdgeWidth = 15.0f;

@implementation WarpEdgeWindow

@synthesize direction = _direction;

+ (WarpEdgeWindow *)windowWithEdge:(Edge *)edge direction:(NSUInteger)direction
{
	return [[[WarpEdgeWindow alloc] initWithEdge:edge direction:direction] autorelease];
}

- (id)initWithEdge:(Edge *)edge direction:(NSUInteger)direction
{
	NSRect contentRect;
	
	if (direction == LeftDirection) {
		contentRect.origin.x = edge->point;
		contentRect.size.width = kWarpEdgeWidth;
		
		contentRect.origin.y = edge->range.location;
		contentRect.size.height = edge->range.length;
	} else if (direction == RightDirection) {
		contentRect.origin.x = edge->point - kWarpEdgeWidth + 1;
		contentRect.size.width = kWarpEdgeWidth;
		
		contentRect.origin.y = edge->range.location;
		contentRect.size.height = edge->range.length;
	} else if (direction == UpDirection) {
		contentRect.origin.y = [edge->screen frame].size.height - kWarpEdgeWidth;
		contentRect.size.height = kWarpEdgeWidth;
		
		contentRect.origin.x = edge->range.location;
		contentRect.size.width = edge->range.length;
	} else if (direction == DownDirection) {
		contentRect.origin.y = [edge->screen frame].origin.y;
		contentRect.size.height = kWarpEdgeWidth;
		
		contentRect.origin.x = edge->range.location;
		contentRect.size.width = edge->range.length;
	} else {
		return nil;
	}
	
	if ( (self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES]) ) {
		_edge = *edge;
		_direction = direction;
		
		[self setContentView:[[[WarpEdgeView alloc] initWithFrame:contentRect] autorelease]];
		[self setLevel:NSScreenSaverWindowLevel];
		[self setBackgroundColor:[NSColor clearColor]];
		[self setOpaque:NO];
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

@end
