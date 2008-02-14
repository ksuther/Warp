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
#import <QuartzCore/QuartzCore.h>

@implementation WarpEdgeView

- (id)initWithFrame:(NSRect)frame
{
	if ( (self = [super initWithFrame:frame]) ) {
		NSTrackingArea *trackingArea = [[[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways owner:self userInfo:nil] autorelease];
		[self addTrackingArea:trackingArea];
		
		_animation = nil;
	}
	return self;
}

- (void)dealloc
{
	[_animation release];
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
	[[[NSColor redColor] colorWithAlphaComponent:0.3f] set];
	[NSBezierPath fillRect:rect];
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

@end
