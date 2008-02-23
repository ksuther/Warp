//
//  WarpEdgeWindow.m
//  Warp
//
//  Created by Kent Sutherland on 2/13/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import "WarpEdgeWindow.h"
#import "WarpEdgeView.h"

static const CGFloat kWarpEdgeWidth = 240.0f;

@implementation WarpEdgeWindow

@synthesize direction = _direction;

+ (WarpEdgeWindow *)windowWithEdge:(Edge *)edge workspace:(NSInteger)workspace direction:(NSUInteger)direction
{
	return [[[WarpEdgeWindow alloc] initWithEdge:edge workspace:workspace direction:direction] autorelease];
}

- (id)initWithEdge:(Edge *)edge workspace:(NSInteger)workspace direction:(NSUInteger)direction
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
		contentRect.origin.y = screenFrame.size.height - height;
		contentRect.origin.x = mouseLoc.x - (width / 2);
		
		contentRect.size.height += 15.0f;
	} else if (direction == DownDirection) {
		contentRect.origin.y = screenFrame.origin.y - 15.0f;
		contentRect.origin.x = mouseLoc.x - (width / 2);
		
		contentRect.size.height += 15.0f;
	} else {
		return nil;
	}
	
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

@end
