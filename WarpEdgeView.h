//
//  WarpEdgeView.h
//  Warp
//
//  Created by Kent Sutherland on 2/13/08.
//  Copyright 2008-2011 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WarpEdgeView : NSView {
	NSTrackingArea *_trackingArea;
	NSViewAnimation *_animation;
	NSImage *_image;
	NSInteger _workspace;
    int _windowCount;
	NSLock *_imageLock;
	
	NSUInteger _direction;
}

@property(retain) NSImage *image;

- (id)initWithFrame:(NSRect)frame workspace:(NSInteger)workspace direction:(NSUInteger)direction;

- (void)fadeOut;

@end
