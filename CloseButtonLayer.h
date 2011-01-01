//
//  CloseButtonLayer.h
//  Warp
//
//  Created by Kent Sutherland on 12/14/08.
//  Copyright 2008-2011 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <QuartzCore/QuartzCore.h>

@interface CloseButtonLayer : CALayer {
	SEL _action;
	id _target;
	
	NSTimer *_closeTimer;
}

@property(assign) SEL action;
@property(assign) id target;

@end
