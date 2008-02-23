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

extern OSStatus CGSGetWindowBounds(NSInteger cid, CGWindowID wid, CGRect *rect);
extern OSStatus CGContextCopyWindowCaptureContentsToRect(CGContextRef ctx, CGRect rect, NSInteger cid, CGWindowID wid, NSInteger flags);

@interface NSApplication (ContextID)
- (NSInteger)contextID;
@end

@interface WarpEdgeView (Private)
- (void)_createThumbnail;
@end

@implementation WarpEdgeView

@synthesize image = _image;

- (id)initWithFrame:(NSRect)frame workspace:(NSInteger)workspace direction:(NSUInteger)direction
{
	if ( (self = [super initWithFrame:frame]) ) {
		_trackingArea = [[[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingAssumeInside owner:self userInfo:nil] autorelease];
		[self addTrackingArea:_trackingArea];
		
		_animation = nil;
		_direction = direction;
		_workspace = workspace;
		_image = nil;
		_imageLock = [[NSLock alloc] init];
		
		CGSGetWorkspaceWindowCount(_CGSDefaultConnection(), workspace + 1, &_windowCount);
		
		[self setWantsLayer:YES];
		[self layer].cornerRadius = 10.0f;
		[self layer].masksToBounds = YES;
		
		CGColorRef color = CGColorCreateGenericGray(1.0f, 1.0f);
		[self layer].borderColor = color;
		[self layer].borderWidth = 2.0f;
		CGColorRelease(color);
		
		//[self _createThumbnail];
		[NSThread detachNewThreadSelector:@selector(_createThumbnail) toTarget:self withObject:nil];
	}
	return self;
}

- (void)dealloc
{
	[_animation release];
	[_image release];
	[_imageLock release];
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor colorWithCalibratedWhite:0.0f alpha:0.7f] set];
	[NSBezierPath fillRect:rect];
	
	if ([self image]) {
		NSPoint drawPoint;
		drawPoint = NSMakePoint(5.0f, 3.0f);
		
		if (_direction == LeftDirection) {
			drawPoint.x = 15.0f;
			drawPoint.y += 1.0f;
		} else if (_direction == RightDirection) {
			drawPoint.x = 5.0f;
			drawPoint.y += 1.0f;
		} else if (_direction == DownDirection) {
			drawPoint.y += 15.0f;
		}
		
		[[self image] compositeToPoint:drawPoint operation:NSCompositeSourceOver];
	} else {
		//No windows on the space, draw no windows text.
		NSString *drawString;
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithCalibratedWhite:0.9f alpha:1.0f], NSForegroundColorAttributeName,
																			[NSFont labelFontOfSize:18.0f], NSFontAttributeName, nil];
		NSRect frame = [self frame];
		
		if (_windowCount == 0) {
			drawString = NSLocalizedString(@"No windows", nil);
		} else {
			drawString = NSLocalizedString(@"Loading", nil);
		}
		
		NSSize size = [drawString sizeWithAttributes:attributes];
		[drawString drawAtPoint:NSMakePoint((frame.size.width - size.width) / 2, (frame.size.height - size.height) / 2) withAttributes:attributes];
	}
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

- (void)setNeedsDisplay
{
	[self setNeedsDisplay:YES];
}

- (NSImage *)image
{
	id tmpImage = nil;
	[_imageLock lock];
	tmpImage = [_image retain];
	[_imageLock unlock];
	
	return [tmpImage autorelease];
}

- (void)setImage:(NSImage *)image
{
	id originalValue;

	[image retain];

	[_imageLock lock];
	originalValue = _image;
	_image = image;
	[_imageLock unlock];

	[originalValue release];
}

- (void)_createThumbnail
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSInteger count = _windowCount, outCount, drawCount = 0;
	
	if (count > 0) {
		NSInteger *list = malloc(sizeof(NSInteger) * count);
		NSInteger *drawList = calloc(count, sizeof(NSInteger));
		CGSGetWorkspaceWindowList(_CGSDefaultConnection(), _workspace + 1, count, list, &outCount);
		
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
		
		NSImage *image = [[NSImage alloc] initWithSize:size];
		[image setCachedSeparately:YES];
		[image lockFocus];
		
		CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
		
		CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
		
		//Determine which windows are top-most so we don't have to draw the windows that aren't even visible
		for (NSInteger i = 0; i < outCount; i++) {
			drawList[drawCount++] = list[i];
		}
		
		for (NSInteger i = drawCount - 1; i >= 0; i--) {
			NSInteger cid = [NSApp contextID];
			
			CGRect cgrect;
			CGSGetWindowBounds(cid, drawList[i], &cgrect);
			
			cgrect.origin.y = screenSize.height - cgrect.size.height - cgrect.origin.y;
			
			CGContextScaleCTM(ctx, size.width / screenSize.width, size.height / screenSize.height);
			CGContextCopyWindowCaptureContentsToRect(ctx, cgrect, cid, drawList[i], 0);
			CGContextScaleCTM(ctx, screenSize.width / size.width, screenSize.height / size.height);
		}
		
		[image unlockFocus];
		
		[self setImage:image];
		
		[self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
	}
	
	[pool release];
}

@end
