//
//  CloseButtonLayer.m
//  Warp
//
//  Created by Kent Sutherland on 12/14/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import "CloseButtonLayer.h"

@implementation CloseButtonLayer

@synthesize action = _action, target = _target;

- (void)closeTimerFired:(NSTimer *)timer
{
	if (GetCurrentKeyModifiers() & optionKey) {
		self.opacity = 1.0;
	} else {
		self.opacity = 0.0;
	}
}

#pragma mark -
#pragma mark NSTrackingArea Callbacks

- (void)mouseEntered:(NSEvent *)event
{
	_closeTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(closeTimerFired:) userInfo:nil repeats:YES];
}

- (void)mouseExited:(NSEvent *)event
{
	[_closeTimer invalidate];
	
	self.opacity = 0.0;
}

@end
