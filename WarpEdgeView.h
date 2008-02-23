//
//  WarpEdgeView.h
//  Warp
//
//  Created by Kent Sutherland on 2/13/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WarpEdgeView : NSView {
	NSTrackingArea *_trackingArea;
	NSViewAnimation *_animation;
	NSImage *_image;
	
	NSUInteger _direction;
}

- (id)initWithFrame:(NSRect)frame workspace:(NSInteger)workspace direction:(NSUInteger)direction;

@end
