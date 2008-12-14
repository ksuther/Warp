//
//  PagerController.m
//  Warp
//
//  Created by Kent Sutherland on 11/21/08.
//  Copyright 2008 Kent Sutherland. All rights reserved.
//

#import "MainController.h"
#import "PagerController.h"
#import "PagerPanel.h"
#import "PagerView.h"
#import "MainController.h"
#import "CGSPrivate2.h"

extern OSStatus CGContextCopyWindowCaptureContentsToRect(CGContextRef ctx, CGRect rect, NSInteger cid, CGWindowID wid, NSInteger flags);

@interface NSApplication (ContextID)
- (NSInteger)contextID;
@end

@interface PagerController (Private)
- (BOOL)_isWarpWindow:(CGSWindowID)wid;
- (void)_createPager;
- (void)_updateActiveSpace;
@end

@implementation PagerController

- (id)init
{
	if ( (self = [super init]) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(spaceDidChange:) name:@"ActiveSpaceDidSwitchNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hoyKeyPressed:) name:@"PagerHotKeyPressed" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenParametersChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
		
		[self _createPager];
		
		[_pagerPanel setAlphaValue:0.0];
		[_pagerPanel orderFront:nil];
		
		_pagerVisible = [[NSUserDefaults standardUserDefaults] boolForKey:@"PagerVisible"];
		
		//Make the pager visible at launch if it was visible last time
		if (_pagerVisible) {
			_pagerVisible = NO;
			[self toggleVisibility];
		}
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_layersView release];
	[_pagerPanel release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Notification Callbacks

- (void)spaceDidChange:(NSNotification *)note
{
	[self _updateActiveSpace];
}

- (void)hoyKeyPressed:(NSNotification *)note
{
	[self toggleVisibility];
}

- (void)screenParametersChanged:(NSNotification *)note
{
	[self performSelector:@selector(updatePager) withObject:nil afterDelay:1.0];
}

- (void)windowMoved:(NSNotification *)note
{
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([_pagerPanel frame]) forKey:@"PagerFrame"];
}

- (void)windowResized:(NSNotification *)note
{
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([_pagerPanel frame]) forKey:@"PagerFrame"];
	
	[_frameLayer setNeedsDisplay];
}

- (void)toggleVisibility
{
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
								_pagerPanel, NSViewAnimationTargetKey,
								_pagerVisible ? NSViewAnimationFadeOutEffect : NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
	NSArray *animations = [NSArray arrayWithObject:dictionary];
	NSViewAnimation *animation = [[[NSViewAnimation alloc] initWithViewAnimations:animations] autorelease];
	
	[animation startAnimation];
	
	_pagerVisible = !_pagerVisible;
	
	[[NSUserDefaults standardUserDefaults] setBool:_pagerVisible forKey:@"PagerVisible"];
}

- (void)updatePager
{
}

- (void)matrixClicked:(id)sender
{
	NSInteger row, col;
	
	[MainController getCurrentSpaceRow:&row column:&col];
	
	if ([sender selectedRow] != row - 1 || [sender selectedColumn] != col - 1) {
		[MainController switchToSpaceRow:[sender selectedRow] + 1 column:[sender selectedColumn] + 1];
	}
}

#pragma mark -
#pragma mark CALayer Delegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
	NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:ctx flipped:NO];
	
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:graphicsContext];
	
	if (layer.zPosition == 0) {
		[NSBezierPath setDefaultLineWidth:5.0];
		
		[[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] set];
		[[NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(layer.bounds) xRadius:12 yRadius:12] fill];
		
		//Draw clear in each of the spaces
		for (CALayer *layer in [[_layersView layer] sublayers]) {
			CGRect frame = [layer convertRect:CGRectInset(layer.frame, -2, -2) toLayer:layer];
			
			frame.origin.x += 8;
			frame.origin.y += 8;
			
			//Clear the rect
			CGContextClearRect(ctx, frame);
			
			[[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] set];
			[[NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(frame) xRadius:6 yRadius:6] stroke];
		}
	} else {
		NSInteger workspace = layer.zPosition;
		NSInteger currentSpace = 0;
		
		if (CGSGetWorkspace(_CGSDefaultConnection(), &currentSpace) == kCGErrorSuccess && workspace == currentSpace) {
			NSDictionary *desktopDict = [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.desktop"] objectForKey:@"Background"] objectForKey:@"default"];
			
			//Draw the desktop background
			NSString *path = [desktopDict objectForKey:@"ImageFilePath"];
			
			if (![[desktopDict objectForKey:@"Change"] isEqualToString:@"Never"]) {
				path = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[desktopDict objectForKey:@"LastName"]];
			}
			
			NSImage *desktopImage = [[NSImage alloc] initByReferencingFile:path];
			[desktopImage drawInRect:NSRectFromCGRect(layer.bounds) fromRect:NSMakeRect(0, 0, desktopImage.size.width, desktopImage.size.height) operation:NSCompositeSourceOver fraction:0.6];
			[desktopImage release];
		} else {
			//Draw the live preview
			NSInteger windowCount;
			CGSGetWorkspaceWindowCount(_CGSDefaultConnection(), workspace, &windowCount);
			
			NSRect cellFrame = NSRectFromCGRect(layer.frame);
			
			if (windowCount > 0) {
				static const CGFloat BorderPercentage = 0.02;
				
				NSInteger outCount;
				NSInteger cid = [NSApp contextID];
				CGRect cgrect;
				
				NSInteger *list = malloc(sizeof(NSInteger) * windowCount);
				CGSGetWorkspaceWindowList(_CGSDefaultConnection(), workspace, windowCount, list, &outCount);
				
				NSSize screenSize = [[NSScreen mainScreen] frame].size;
				NSSize size = NSInsetRect(cellFrame, cellFrame.size.width * BorderPercentage, cellFrame.size.height * BorderPercentage).size;
				CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
				
				CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
				
				CGContextTranslateCTM(ctx, cellFrame.size.width * BorderPercentage, (cellFrame.size.height * BorderPercentage) * 1.5);
				
				for (NSInteger i = outCount - 1; i >= 0; i--) {
					if (![self _isWarpWindow:list[i]]) {
						CGSGetWindowBounds(cid, list[i], &cgrect);
						
						cgrect.origin.y = screenSize.height - cgrect.size.height - cgrect.origin.y;
						
						//CGContextTranslateCTM(ctx, 0, size.height);
						CGContextScaleCTM(ctx, size.width / screenSize.width, size.height / screenSize.height);
						CGContextCopyWindowCaptureContentsToRect(ctx, cgrect, cid, list[i], 0);
						CGContextScaleCTM(ctx, screenSize.width / size.width, screenSize.height / size.height);
						//CGContextTranslateCTM(ctx, 0, -size.height);
					}
				}
				
				free(list);
			}
		}
	}
	
	[NSGraphicsContext restoreGraphicsState];
}

#pragma mark -
#pragma mark NSTrackingArea Callbacks

- (void)mouseEntered:(NSEvent *)event
{
	//Show the close button
}

- (void)mouseExited:(NSEvent *)event
{
	//Hide the close button
}

#pragma mark -
#pragma mark Private

- (void)_createPager
{
	CGFloat ratio = (CGFloat)CGDisplayPixelsWide(kCGDirectMainDisplay) / CGDisplayPixelsHigh(kCGDirectMainDisplay);
	NSSize pagerSize = NSMakeSize(320, 320 / ratio);
	
	_pagerPanel = [[PagerPanel alloc] initWithContentRect:NSMakeRect(0, 0, pagerSize.width, pagerSize.height)
											 styleMask:NSUtilityWindowMask | NSNonactivatingPanelMask
											   backing:NSBackingStoreBuffered defer:NO];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowMoved:) name:NSWindowDidMoveNotification object:_pagerPanel];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowResized:) name:NSWindowDidResizeNotification object:_pagerPanel];
	
	NSView *contentView = [[[NSView alloc] initWithFrame:[_pagerPanel frame]] autorelease];
	[contentView setWantsLayer:YES];
	[_pagerPanel setContentView:contentView];
	
	NSString *savedFrameString = [[NSUserDefaults standardUserDefaults] stringForKey:@"PagerFrame"];
	NSRect savedFrame = NSRectFromString(savedFrameString);
	
	if (savedFrameString && !NSEqualRects(savedFrame, NSZeroRect)) {
		[_pagerPanel setFrame:savedFrame display:NO];
	}
	
	[_pagerPanel setBackgroundColor:[NSColor clearColor]];
	[_pagerPanel setOpaque:NO];
	[_pagerPanel setContentAspectRatio:pagerSize];
	[_pagerPanel setMinSize:NSMakeSize(100, 100)];
	[_pagerPanel setMaxSize:NSMakeSize(500, 500)];
	[_pagerPanel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	[_pagerPanel setLevel:NSStatusWindowLevel];
	[_pagerPanel setDelegate:self];
	
	_layersView = [[PagerView alloc] initWithFrame:NSInsetRect([[_pagerPanel contentView] bounds], 8, 8)];
	[_layersView setWantsLayer:YES];
	[_layersView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[_layersView layer].layoutManager = [CAConstraintLayoutManager layoutManager];
	[_layersView layer].zPosition = -1;
	
	[[_pagerPanel contentView] addSubview:_layersView];
	
	NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:NSMakeRect(0, [[_pagerPanel contentView] bounds].size.height - 15, 15, 15) options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways owner:self userInfo:nil];
	[[_pagerPanel contentView] addTrackingArea:area];
	
	NSInteger cols = [MainController numberOfSpacesColumns], rows = [MainController numberOfSpacesRows];
	//NSInteger cols = 3, rows = 3;
	NSSize layerSize = NSMakeSize(pagerSize.width - (cols + 1) * 3, pagerSize.height - (rows + 1) * 3);
	
	for (NSInteger i = 0; i < rows; i++) {
		for (NSInteger j = 0; j < cols; j++) {
			CALayer *layer = [CALayer layer];
			
			layer.name = [NSString stringWithFormat:@"%d.%d", i, j];
			
			CGColorRef color = CGColorCreateGenericGray(0.0, 0.25);
			layer.backgroundColor = color;
			layer.borderColor = CGColorGetConstantColor(kCGColorClear);
			CGColorRelease(color);
			
			layer.delegate = self;
			layer.cornerRadius = 5.0;
			layer.borderWidth = 2.0;
			layer.masksToBounds = YES;
			layer.opacity = 1.0;
			layer.zPosition = [MainController spacesIndexForRow:i + 1 column:j + 1] + 1;
			layer.bounds = CGRectMake(0, 0, (layerSize.width / cols), (layerSize.height / rows));
			
			[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintWidth relativeTo:@"superlayer" attribute:kCAConstraintWidth scale:(1.0 / cols) offset:-3]];
			[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintHeight relativeTo:@"superlayer" attribute:kCAConstraintHeight scale:(1.0 / rows) offset:-3]];
			
			if (j == 0) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:@"superlayer" attribute:kCAConstraintMinX offset:0]];
			}
			
			if (i == 0) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY offset:0]];
			}
			
			if (i > 0) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:[NSString stringWithFormat:@"%d.%d", i - 1, j] attribute:kCAConstraintMinY offset:-5]];
			}
			
			if (j > 0) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:[NSString stringWithFormat:@"%d.%d", i, j - 1] attribute:kCAConstraintMaxX offset:5]];
			}
			
			[[_layersView layer] addSublayer:layer];
			
			[layer setNeedsDisplay];
		}
	}
	
	_frameLayer = [CALayer layer];
	_frameLayer.opacity = 0.85;
	_frameLayer.delegate = self;
	_frameLayer.frame = [[_pagerPanel contentView] layer].frame;
	_frameLayer.contentsGravity = kCAGravityResize;
	_frameLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
	[_frameLayer setNeedsDisplay];
	[[[_pagerPanel contentView] layer] addSublayer:_frameLayer];
	
	[self _updateActiveSpace];
}

- (void)_updateActiveSpace
{
	NSInteger previousSpace = _activeSpace;
	
	CGSGetWorkspace(_CGSDefaultConnection(), &_activeSpace);
	
	for (CALayer *layer in [[_layersView layer] sublayers]) {
		if (layer.zPosition == previousSpace) {
			layer.borderColor = CGColorGetConstantColor(kCGColorClear);
			
			CATransition *transition = [CATransition animation];
			transition.duration = 0.5;
			[layer addAnimation:transition forKey:kCATransition];
			[layer setNeedsDisplay];
		} else if (layer.zPosition == _activeSpace) {
			CGColorRef color = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
			layer.borderColor = color;
			CGColorRelease(color);
			
			CATransition *transition = [CATransition animation];
			transition.duration = 0.5;
			[layer addAnimation:transition forKey:kCATransition];
			[layer setNeedsDisplay];
		}
	}
	
	[[_layersView layer] setNeedsLayout];
}

- (BOOL)_isWarpWindow:(CGSWindowID)wid
{
	for (NSWindow *window in [NSApp windows]) {
		if ([window windowNumber] == wid) {
			return YES;
		}
	}
	
	return NO;
}

@end
