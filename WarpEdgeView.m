//
//  WarpEdgeView.m
//  Warp
//
//  Created by Kent Sutherland on 2/13/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import "WarpEdgeView.h"
#import "WarpEdgeWindow.h"
#import "MainController.h"
#import "CoreGraphicsPrivate.h"
#import <QuartzCore/QuartzCore.h>

@interface WarpEdgeView (Private)
- (void)_createThumbnailForWorkspace:(NSInteger)workspace;
@end

@implementation WarpEdgeView

- (id)initWithFrame:(NSRect)frame workspace:(NSInteger)workspace direction:(NSUInteger)direction
{
	if ( (self = [super initWithFrame:frame]) ) {
		_trackingArea = [[[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingAssumeInside owner:self userInfo:nil] autorelease];
		[self addTrackingArea:_trackingArea];
		
		_animation = nil;
		_direction = direction;
		
		[self setWantsLayer:YES];
		[self layer].cornerRadius = 10.0f;
		[self layer].masksToBounds = YES;
		
		CGColorRef color = CGColorCreateGenericGray(1.0f, 1.0f);
		[self layer].borderColor = color;
		[self layer].borderWidth = 2.0f;
		CGColorRelease(color);
		
		[self _createThumbnailForWorkspace:workspace];
	}
	return self;
}

- (void)dealloc
{
	[_animation release];
	[_image release];
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor colorWithCalibratedWhite:0.0f alpha:0.7f] set];
	[NSBezierPath fillRect:rect];
	
	NSPoint drawPoint;
	drawPoint = NSMakePoint(5.0f, 0.0f);
	
	if (_direction == LeftDirection) {
		drawPoint.x = 15.0f;
	} else if (_direction == RightDirection) {
		drawPoint.x = 5.0f;
	} else if (_direction == DownDirection) {
		drawPoint.y = 15.0f;
	}
	
	[_image compositeToPoint:drawPoint operation:NSCompositeSourceOver];
}

- (BOOL)acceptsFirstResponder
{
	return NO;
}

- (BOOL)canBecomeKeyView
{
	return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
	return YES;
}

- (void)mouseDown:(NSEvent *)event
{
	[MainController warpInDirection:[(WarpEdgeWindow *)[self window] direction]];
}

- (void)mouseEntered:(NSEvent *)event
{
	if (_animation) {
		NSAnimationProgress progress = [_animation currentProgress];
		
		[_animation stopAnimation];
		
		NSDictionary *animationDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[self window], NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
		_animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animationDictionary]];
		[_animation setCurrentProgress:1 - progress];
		[_animation startAnimation];
	}
}

- (void)mouseExited:(NSEvent *)event
{
	if (_animation) {
		[_animation stopAnimation];
		[_animation release];
	}
	
	NSDictionary *animationDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[self window], NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
	_animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animationDictionary]];
	
	[_animation setDelegate:self];
	[_animation startAnimation];
	
	[self removeTrackingArea:_trackingArea];
}

- (BOOL)isOpaque
{
	return NO;
}

- (void)animationDidEnd:(NSAnimation *)animation
{
	[[self window] orderOut:nil];
	
	[_animation release];
	_animation = nil;
}

- (void)_createThumbnailForWorkspace:(NSInteger)workspace
{
	NSInteger count, outCount;
	CGSGetWorkspaceWindowCount(_CGSDefaultConnection(), workspace + 1, &count);
	
	NSInteger *list = malloc(sizeof(NSInteger) * count);
	CGSGetWorkspaceWindowList(_CGSDefaultConnection(), workspace + 1, count, list, &outCount);
	
	NSSize screenSize = [[NSScreen mainScreen] frame].size;
	NSSize size = [self frame].size;
	
	if (_direction == LeftDirection) {
		size.width -= 21.0f;
	} else if (_direction == RightDirection) {
		size.width -= 27.0f;
	} else {
		size.width -= 10.0f;
	}
	
	size.height -= (_direction == UpDirection || _direction == DownDirection) ? 21.0f : 6.0f;
	
	[_image release];
	_image = [[NSImage alloc] initWithSize:size];
	
	[_image lockFocus];
	CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
	
	CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
	
	NSInteger i;
	for (i = outCount - 1; i >= 0; i--) {
		NSInteger cid = (NSInteger)[NSApp contextID];
		
		CGRect cgrect;
		CGSGetWindowBounds(cid, list[i], &cgrect);
		
		cgrect.origin.y = screenSize.height - cgrect.size.height - cgrect.origin.y;
		
		CGContextScaleCTM(ctx, size.width / screenSize.width, size.height / screenSize.height);
		CGContextCopyWindowCaptureContentsToRect(ctx, cgrect, cid, list[i], 0);
		CGContextScaleCTM(ctx, screenSize.width / size.width, screenSize.height / size.height);
	}
	
	[_image unlockFocus];
}

@end
