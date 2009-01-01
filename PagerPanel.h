//
//  PagerPanel.h
//  Warp
//
//  Created by Kent Sutherland on 11/21/08.
//  Copyright 2008-2009 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface PagerPanel : NSPanel {
	NSPoint _initialLocation;
	NSPoint _initialLocationOnScreen;
	NSRect _initialFrame;
	BOOL _resizing, _dragged;
	
	CALayer *_downLayer;
}

@end
