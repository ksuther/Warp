//
//  WarpEdgeWindow.h
//  Warp
//
//  Created by Kent Sutherland on 2/13/08.
//  Copyright 2008-2009 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainController.h"

@interface WarpEdgeWindow : NSWindow {
	Edge _edge;
	NSUInteger _direction;
	BOOL _exited;
}

@property(assign) NSUInteger direction;

+ (WarpEdgeWindow *)windowWithEdge:(Edge *)edge workspace:(NSInteger)workspace direction:(NSUInteger)direction;
+ (NSRect)frameForEdge:(Edge *)edge direction:(NSUInteger)direction;

- (id)initWithEdge:(Edge *)edge workspace:(NSInteger)workspace direction:(NSUInteger)direction;

- (Edge *)edge;
- (void)setEdge:(Edge *)edge;

- (void)fadeOut;

@end
