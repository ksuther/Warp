//
//  PagerController.h
//  Warp
//
//  Created by Kent Sutherland on 11/21/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface PagerController : NSObject {
	NSPanel *_pagerPanel;
	NSView *_layersView;
	
	CALayer *_closeLayer, *_frameLayer;
	
	NSInteger _activeSpace;
}

@end
