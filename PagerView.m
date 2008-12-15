//
//  PagerView.m
//  Warp
//
//  Created by Kent Sutherland on 11/22/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "PagerView.h"
#import "MainController.h"

@implementation PagerView

- (void)mouseDragged:(NSEvent *)event
{
	_dragged = YES;
	
	[super mouseDragged:event];
}

- (void)mouseUp:(NSEvent *)event
{
	if (!_dragged) {
		CALayer *clickedLayer = [[self layer] hitTest:NSPointToCGPoint([event locationInWindow])];
		
		if (clickedLayer && clickedLayer.zPosition >= 0) {
			[MainController switchToSpaceIndex:clickedLayer.zPosition - 1];
		}
	}
	
	_dragged = NO;
	
	[super mouseUp:event];
}

- (void)viewDidEndLiveResize
{
	[[[self layer] sublayers] makeObjectsPerformSelector:@selector(setNeedsDisplay)];
}

@end
