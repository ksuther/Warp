//
//  PagerController.h
//  Warp
//
//  Created by Kent Sutherland on 11/21/08.
//  Copyright 2008-2011 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "CGSPrivate.h"

typedef enum PagerStyle {
	PagerStyleWindowContents = 0,
	PagerStyleWindowBordersAndIcons,
} PagerStyle;

@class CloseButtonLayer;

@interface PagerController : NSObject {
	BOOL _pagerVisible;
	NSPanel *_pagerPanel;
	NSView *_layersView;
	
	NSTimer *_updateTimer;
	
	CALayer *_frameLayer;
	CloseButtonLayer *_closeLayer;
	NSTrackingArea *_closeTrackingArea;
	
	CGSWorkspace _activeSpace;
}

- (void)hidePager;
- (void)showPager;
- (void)toggleVisibility;

@end
