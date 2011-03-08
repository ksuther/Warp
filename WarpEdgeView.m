/*
 * WarpEdgeView.m
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

#import "WarpEdgeView.h"
#import "WarpEdgeWindow.h"
#import "MainController.h"
#import "CGSPrivate.h"
#import <QuartzCore/QuartzCore.h>

extern OSStatus CGContextCopyWindowCaptureContentsToRect(CGContextRef ctx, CGRect rect, NSInteger cid, CGWindowID wid, NSInteger flags);

@interface NSApplication (ContextID)
- (NSInteger)contextID;
@end

@interface WarpEdgeView (Private)
- (void)_createThumbnail;
- (BOOL)_isWarpWindow:(CGSWindowID)wid;
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
		
		CGColorRef borderColor = CGColorCreateGenericGray(1.0f, 1.0f);
		[self layer].borderColor = borderColor;
		[self layer].borderWidth = 2.0f;
		CGColorRelease(borderColor);
		
		CGColorRef backgroundColor = CGColorCreateGenericGray(0.0f, 0.7f);
		[self layer].backgroundColor = backgroundColor;
		CGColorRelease(backgroundColor);
		
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
	} else if (_windowCount == 0) {
		//No windows on the space, draw no windows text.
		NSRect frame = [self frame];
		NSString *drawString = NSLocalizedString(@"No windows", nil);
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithCalibratedWhite:0.9f alpha:1.0f], NSForegroundColorAttributeName,
																			[NSFont labelFontOfSize:18.0f], NSFontAttributeName, nil];
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
	[MainController warpInDirection:[(WarpEdgeWindow *)[self window] direction] edge:[(WarpEdgeWindow *)[self window] edge]];
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
	[self fadeOut];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
	[self mouseDown:event];
	
	return nil;
}

- (BOOL)isOpaque
{
	return NO;
}

- (void)fadeOut
{
	if (_animation) {
		[_animation stopAnimation];
		[_animation release];
	}
	
	NSDictionary *animationDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[self window], NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
	_animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animationDictionary]];
	
	[_animation setDelegate:self];
	[_animation startAnimation];
	
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
        _trackingArea = nil;
    }
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

#pragma mark -
#pragma mark Private

- (void)_createThumbnail
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSInteger count = _windowCount;
	
	if (count > 0) {
		int outCount;
		NSInteger cid = [NSApp contextID];
		CGRect cgrect;
		
		int *list = malloc(sizeof(int) * count);
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
		
		for (NSInteger i = outCount - 1; i >= 0; i--) {
			if (![self _isWarpWindow:list[i]]) {
				CGSGetWindowBounds(cid, list[i], &cgrect);
				
				cgrect.origin.y = screenSize.height - cgrect.size.height - cgrect.origin.y;
				
				CGContextScaleCTM(ctx, size.width / screenSize.width, size.height / screenSize.height);
				CGContextCopyWindowCaptureContentsToRect(ctx, cgrect, cid, list[i], 0);
				CGContextScaleCTM(ctx, screenSize.width / size.width, screenSize.height / size.height);
			}
		}
		
		[image unlockFocus];
		
		[self setImage:image];
		[self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
		
		free(list);
	}
	
	[pool release];
}

- (BOOL)_isWarpWindow:(CGSWindowID)wid
{
	for (NSWindow *window in [NSApp windows]) {
		if ([window windowNumber] == wid) {
			return YES;
		}
	}
	
	return NO;
}

@end
