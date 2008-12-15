//
//  PagerPanel.m
//  Warp
//
//  Created by Kent Sutherland on 11/21/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import "PagerPanel.h"
#import "CloseButtonLayer.h"

static const NSInteger PagerResizeCornerSize = 10;

@implementation PagerPanel

- (BOOL)canBecomeMainWindow
{
	return NO;
}

- (BOOL)canBecomeKeyWindow
{
	return NO;
}

- (void)mouseDown:(NSEvent *)event
{
	_initialLocation = [event locationInWindow];
	_initialLocationOnScreen = [self convertBaseToScreen:[event locationInWindow]];
	_initialFrame = [self frame];
	
	_resizing = (_initialLocation.x >= _initialFrame.size.width - PagerResizeCornerSize && _initialLocation.y <= PagerResizeCornerSize);
	
	_downLayer = [[[self contentView] layer] hitTest:NSPointToCGPoint([event locationInWindow])];
}

- (void)mouseUp:(NSEvent *)event
{
	if (_resizing) {
		[[[self contentView] subviews] makeObjectsPerformSelector:@selector(viewDidEndLiveResize)];
	} else if (!_dragged) {
		CALayer *layer = [[[self contentView] layer] hitTest:NSPointToCGPoint([event locationInWindow])];
		
		if (layer == _downLayer && [layer isKindOfClass:[CloseButtonLayer class]] && [(CloseButtonLayer *)layer target] && [(CloseButtonLayer *)layer action]) {
			[[(CloseButtonLayer *)layer target] performSelector:[(CloseButtonLayer *)layer action]];
		}
	}
	
	_dragged = NO;
}

- (void)mouseDragged:(NSEvent *)event
{
	NSPoint currentLocation, newOrigin;
	NSRect screenFrame = [[NSScreen mainScreen] frame];
	NSRect frame = [self frame];
	
	_dragged = YES;
	
	//from http://www.cocoadev.com/index.pl?BorderlessWindow
	if (_resizing) {
		NSPoint currentLocationOnScreen = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
		currentLocation = [event locationInWindow];
		
		// ii. Adjust the frame size accordingly
		frame.size.width = _initialFrame.size.width + (currentLocation.x - _initialLocation.x);
		CGFloat heightDelta = (currentLocationOnScreen.y - _initialLocationOnScreen.y);
		
		frame.size.height = (_initialFrame.size.height - heightDelta);
		frame.origin.y = (_initialFrame.origin.y + heightDelta); 
		
		//Ensure we're not going out of range of max or min size
		NSSize minSize = [self minSize], maxSize = [self maxSize];
		CGFloat constraintedHeight = MAX(MIN(frame.size.height, maxSize.height), minSize.height);
		
		//Adjust the frame origin if the height was constrained
		if (constraintedHeight != frame.size.height) {
			frame.origin.y += frame.size.height - constraintedHeight;
			frame.size.height = constraintedHeight;
		}
		
		frame.size.width = MAX(MIN(frame.size.width, maxSize.width), minSize.width);
		
		//Preserve aspect ratio
		NSSize aspect = [self contentAspectRatio];
		
		constraintedHeight = frame.size.width * (aspect.height / aspect.width);
		frame.origin.y += frame.size.height - constraintedHeight;
		frame.size.height = constraintedHeight;
		
		// iii. Set
		[self setFrame:frame display:YES animate:NO];
	} else {
		//Move the window
		currentLocation = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
		newOrigin.x = currentLocation.x - _initialLocation.x;
		newOrigin.y = currentLocation.y - _initialLocation.y;
		
		//Don't let window get dragged up under the menu bar
		if ((newOrigin.y + frame.size.height) > (screenFrame.origin.y + screenFrame.size.height)){
			newOrigin.y = screenFrame.origin.y + (screenFrame.size.height - frame.size.height);
		}
		
		[self setFrameOrigin:newOrigin];
	}
}

@end
