/*
 * CloseButtonLayer.m
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
	_closeTimer = nil;
	
	self.opacity = 0.0;
}

@end
