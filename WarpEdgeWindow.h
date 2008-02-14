//
//  WarpEdgeWindow.h
//  Warp
//
//  Created by Kent Sutherland on 2/13/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainController.h"

@interface WarpEdgeWindow : NSWindow {
	Edge _edge;
	NSUInteger _direction;
}

@property(assign) NSUInteger direction;

+ (WarpEdgeWindow *)windowWithEdge:(Edge *)edge direction:(NSUInteger)direction;

- (id)initWithEdge:(Edge *)edge direction:(NSUInteger)direction;
- (Edge *)edge;
- (void)setEdge:(Edge *)edge;

@end
