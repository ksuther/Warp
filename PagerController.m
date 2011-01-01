//
//  PagerController.m
//  Warp
//
//  Created by Kent Sutherland on 11/21/08.
//  Copyright 2008-2011 Kent Sutherland. All rights reserved.
//

#import "MainController.h"
#import "PagerController.h"
#import "PagerPanel.h"
#import "PagerView.h"
#import "MainController.h"
#import "CloseButtonLayer.h"

extern OSStatus CGContextCopyWindowCaptureContentsToRect(CGContextRef ctx, CGRect rect, NSInteger cid, CGWindowID wid, NSInteger flags);

static const CGFloat PagerBorderGray = 0.2;
static const CGFloat PagerBorderAlpha = 0.6;
static const CGFloat PagerBorderWidth = 5;

@interface NSApplication (ContextID)
- (NSInteger)contextID;
@end

@interface PagerController (Private)
- (void)_createPager;
- (void)_updatePagerSize:(BOOL)animate;
- (void)_createSpacesLayers;
- (void)_updateActiveSpace;
- (void)_resetTrackingArea;
- (void)_savePagerDefaults;
- (BOOL)_isWarpWindow:(CGSWindowID)wid;
@end

@implementation PagerController

- (id)init
{
	if ( (self = [super init]) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(spaceDidChange:) name:@"ActiveSpaceDidSwitchNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePager) name:@"SpacesConfigurationDidChangeNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hoyKeyPressed:) name:@"PagerHotKeyPressed" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePager) name:NSApplicationDidChangeScreenParametersNotification object:nil];
		
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
	
	[_updateTimer invalidate];
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

- (void)windowMoved:(NSNotification *)note
{
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(_savePagerDefaults) object:nil];
	[self performSelector:@selector(_savePagerDefaults) withObject:nil afterDelay:0.0];
}

- (void)windowResized:(NSNotification *)note
{
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(_savePagerDefaults) object:nil];
	[self performSelector:@selector(_savePagerDefaults) withObject:nil afterDelay:0.0];
	
	[self _resetTrackingArea];
	[_frameLayer setNeedsDisplay];
}

- (void)hidePager
{
	if (_pagerVisible) {
		[self toggleVisibility];
	}
}

- (void)showPager
{
	if (!_pagerVisible) {
		[self toggleVisibility];
	}
}

- (void)toggleVisibility
{
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
								_pagerPanel, NSViewAnimationTargetKey,
								_pagerVisible ? NSViewAnimationFadeOutEffect : NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
	NSArray *animations = [NSArray arrayWithObject:dictionary];
	NSViewAnimation *animation = [[[NSViewAnimation alloc] initWithViewAnimations:animations] autorelease];
	
	[animation setDuration:0.25];
	[animation startAnimation];
	
	_pagerVisible = !_pagerVisible;
	
	[[NSUserDefaults standardUserDefaults] setBool:_pagerVisible forKey:@"PagerVisible"];
	
	if (_pagerVisible) {
		[self performSelector:@selector(_updateActiveSpace) withObject:nil afterDelay:0.25];
		_updateTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(_updateActiveSpace) userInfo:nil repeats:YES];
	} else {
		[_updateTimer invalidate];
		_updateTimer = nil;
	}
}

- (void)updatePager
{
	NSArray *layers = [NSArray arrayWithArray:[[_layersView layer] sublayers]];
	
	for (CALayer *layer in layers) {
		[layer removeFromSuperlayer];
	}
	
	[self _updatePagerSize:YES];
	[self _createSpacesLayers];
	[self _updateActiveSpace];
	[_frameLayer setNeedsDisplay];
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
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(layer.bounds) xRadius:12 yRadius:12];
		
		[NSBezierPath setDefaultLineWidth:0.5];
		
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.9] set];
		[borderPath fill];
		
		[[NSColor colorWithCalibratedWhite:PagerBorderGray alpha:PagerBorderAlpha] set];
		[borderPath stroke];
		
		//Draw clear in each of the spaces
		for (CALayer *layer in [[_layersView layer] sublayers]) {
			CGRect frame = [layer convertRect:layer.frame toLayer:layer];
			frame.origin.x += PagerBorderWidth;
			
			//Clear the area of each space
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeClear];
			[[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] set];
			[[NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(frame) xRadius:6 yRadius:6] fill];
		}
	} else {
		NSInteger workspace = layer.zPosition;
		CGSWorkspace currentSpace = 0;
		
		//Draw the desktop background for the active space
		if (CGSGetWorkspace(_CGSDefaultConnection(), &currentSpace) == kCGErrorSuccess && workspace == currentSpace) {
			NSDictionary *desktopDict = [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.desktop"] objectForKey:@"Background"] objectForKey:@"default"];
			
			NSString *path = [desktopDict objectForKey:@"ImageFilePath"];
			id change = [desktopDict objectForKey:@"Change"];
			
			if (change && ![change isEqualToString:@"Never"]) {
				path = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[desktopDict objectForKey:@"LastName"]];
			}
			
			NSImage *desktopImage = [[NSImage alloc] initByReferencingFile:path];
			
			[desktopImage drawInRect:NSRectFromCGRect(layer.bounds) fromRect:NSMakeRect(0, 0, desktopImage.size.width, desktopImage.size.height) operation:NSCompositeSourceOver fraction:0.2];
			[desktopImage release];
		}
		
		//Draw the live preview
		int windowCount;
		CGSGetWorkspaceWindowCount(_CGSDefaultConnection(), workspace, &windowCount);
		
		NSRect cellFrame = NSRectFromCGRect(layer.frame);
		
		if (windowCount > 0) {
			static const CGFloat BorderPercentage = 0.02;
			
			int outCount;
			NSInteger cid = [NSApp contextID];
			CGRect cgrect;
			
			CGColorRef borderColor = CGColorCreateGenericGray(0.5, 1.0);
			
			int *list = malloc(sizeof(int) * windowCount);
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
					
					if ([[NSUserDefaults standardUserDefaults] integerForKey:@"PagerStyle"] == PagerStyleWindowContents) {
						CGContextScaleCTM(ctx, size.width / screenSize.width, size.height / screenSize.height);
						CGContextCopyWindowCaptureContentsToRect(ctx, cgrect, cid, list[i], 0);
						CGContextScaleCTM(ctx, screenSize.width / size.width, screenSize.height / size.height);
					} else {
						CGRect windowRect = cgrect;
						
						windowRect.origin.x = (cgrect.origin.x / screenSize.width) * size.width;
						windowRect.origin.y = (cgrect.origin.y / screenSize.height) * size.height;
						windowRect.size.width *= size.width / screenSize.width;
						windowRect.size.height *= size.height / screenSize.height;
						
						//Fill and stroke the window rect
						CGContextSetFillColorWithColor(ctx, CGColorGetConstantColor(kCGColorWhite));
						CGContextFillRect(ctx, windowRect);
						
						CGContextSetStrokeColorWithColor(ctx, borderColor);
						CGContextStrokeRect(ctx, windowRect);
						
						//Get the application icon for this window
						CGSConnection windowConncection;
						CGError error;
						pid_t pid;
						ProcessSerialNumber psn;
						FSRef processLocation;
						
						error = CGSGetWindowOwner(_CGSDefaultConnection(), list[i], &windowConncection);
						NSAssert1(error == noErr, @"CGSGetWindowOwner() failed! %d", error);
						
						error = CGSConnectionGetPID(windowConncection, &pid, windowConncection);
						NSAssert1(error == noErr, @"CGSConnectionGetPID() failed! %d", error);
						
						error = GetProcessForPID(pid, &psn);
						NSAssert1(error == noErr, @"GetProcessForPID() failed! %d", error);
						
						error = GetProcessBundleLocation(&psn, &processLocation);
						NSAssert1(error == noErr, @"GetProcessBundleLocation() failed! %d", error);
						
						NSURL *applicationURL = (NSURL *)CFURLCreateFromFSRef(kCFAllocatorDefault, &processLocation);
						
						NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:[applicationURL path]];
						NSSize imageSize = image.size;
						
						NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithGraphicsPort:ctx flipped:NO];
						[NSGraphicsContext saveGraphicsState];
						[NSGraphicsContext setCurrentContext:context];
						
						NSRect iconRect = NSRectFromCGRect(cgrect);
						
						iconRect.origin.x = ((iconRect.origin.x + (iconRect.size.width / 2)) / screenSize.width) * size.width - 8;
						iconRect.origin.y = ((iconRect.origin.y + (iconRect.size.height / 2)) / screenSize.height) * size.height - 8;
						iconRect.size.width = 16;
						iconRect.size.height = 16;
						
						[image drawInRect:iconRect fromRect:NSMakeRect(0, 0, imageSize.width, imageSize.height) operation:NSCompositeSourceOver fraction:1.0];
						
						[NSGraphicsContext restoreGraphicsState];
					}
				}
			}
			
			free(list);
			
			CGColorRelease(borderColor);
		}
	}
	
	[NSGraphicsContext restoreGraphicsState];
}

#pragma mark -
#pragma mark Private

- (void)_createPager
{
	CGFloat ratio = (CGFloat)CGDisplayPixelsWide(kCGDirectMainDisplay) / CGDisplayPixelsHigh(kCGDirectMainDisplay);
	NSSize pagerSize = NSMakeSize(320, 320 / ratio);
	NSString *pagerOriginString = [[NSUserDefaults standardUserDefaults] stringForKey:@"PagerOrigin"];
	NSPoint pagerOrigin = NSPointFromString(pagerOriginString);
	
	//Ensure the pager will be created with a sane size and width
	if (!pagerOriginString || NSEqualPoints(pagerOrigin, NSZeroPoint)) {
		pagerOrigin = NSMakePoint(50, CGDisplayPixelsHigh(kCGDirectMainDisplay) - pagerSize.height - 50);
	}
	
	_pagerPanel = [[PagerPanel alloc] initWithContentRect:NSMakeRect(pagerOrigin.x, pagerOrigin.y, 0, 0)
											 styleMask:NSUtilityWindowMask | NSNonactivatingPanelMask
											   backing:NSBackingStoreBuffered defer:NO];
	
	NSView *contentView = [[[NSView alloc] initWithFrame:[_pagerPanel frame]] autorelease];
	[contentView setWantsLayer:YES];
	[_pagerPanel setContentView:contentView];
	
	[self _updatePagerSize:NO];
	
	[_pagerPanel setBackgroundColor:[NSColor clearColor]];
	[_pagerPanel setOpaque:NO];
	[_pagerPanel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	[_pagerPanel setLevel:NSStatusWindowLevel];
	
	[_pagerPanel setDelegate:self];
	
	NSRect layersRect = NSInsetRect([[_pagerPanel contentView] bounds], PagerBorderWidth, PagerBorderWidth);
	layersRect.origin.y -= PagerBorderWidth;
	layersRect.size.width += PagerBorderWidth;
	layersRect.size.height += PagerBorderWidth;
	
	_layersView = [[PagerView alloc] initWithFrame:layersRect];
	[_layersView setWantsLayer:YES];
	[_layersView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[_layersView layer].layoutManager = [CAConstraintLayoutManager layoutManager];
	[_layersView layer].zPosition = -1;
	
	[[_pagerPanel contentView] addSubview:_layersView];
	
	_frameLayer = [CALayer layer];
	_frameLayer.opacity = 0.9;
	_frameLayer.delegate = self;
	_frameLayer.frame = [[_pagerPanel contentView] layer].frame;
	_frameLayer.contentsGravity = kCAGravityResize;
	_frameLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
	[_frameLayer setNeedsDisplay];
	[[[_pagerPanel contentView] layer] addSublayer:_frameLayer];
	
	//Add the corner resize indicator
	CFURLRef url = CFBundleCopyResourceURL(CFBundleGetMainBundle(), CFSTR("resize_corner"), CFSTR("png"), nil);
	CGDataProviderRef provider = CGDataProviderCreateWithURL(url);
	CGImageRef resizeImage = CGImageCreateWithPNGDataProvider(provider, NULL, false, kCGRenderingIntentDefault);
	CALayer *resizeLayer = [CALayer layer];
	
	resizeLayer.autoresizingMask = kCALayerMinXMargin | kCALayerMaxYMargin;
	resizeLayer.frame = CGRectMake(_pagerPanel.frame.size.width - (PagerBorderWidth + 4), 4, PagerBorderWidth, PagerBorderWidth);
	resizeLayer.contents = (id)resizeImage;
	[[[_pagerPanel contentView] layer] addSublayer:resizeLayer];
	
	CGImageRelease(resizeImage);
	CGDataProviderRelease(provider);
	CFRelease(url);
	
	url = CFBundleCopyResourceURL(CFBundleGetMainBundle(), CFSTR("closebox"), CFSTR("png"), nil);
	provider = CGDataProviderCreateWithURL(url);
	CGImageRef closeImage = CGImageCreateWithPNGDataProvider(provider, NULL, false, kCGRenderingIntentDefault);
	
	_closeLayer = [CloseButtonLayer layer];
	_closeLayer.frame = CGRectMake(0, _pagerPanel.frame.size.height - 30, 30, 30);
	_closeLayer.autoresizingMask = kCALayerMinYMargin;
	_closeLayer.contents = (id)closeImage;
	_closeLayer.opacity = 0.0;
	_closeLayer.target = self;
	_closeLayer.action = @selector(hidePager);
	[[[_pagerPanel contentView] layer] addSublayer:_closeLayer];
	
	CGImageRelease(closeImage);
	CGDataProviderRelease(provider);
	CFRelease(url);
	
	[self _createSpacesLayers];
	[self _updateActiveSpace];
	[self _resetTrackingArea];
	
	[self performSelector:@selector(_savePagerDefaults) withObject:nil afterDelay:0.0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowMoved:) name:NSWindowDidMoveNotification object:_pagerPanel];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowResized:) name:NSWindowDidResizeNotification object:_pagerPanel];
}

- (void)_updatePagerSize:(BOOL)animate;
{
	CGFloat ratio = (CGFloat)CGDisplayPixelsWide(kCGDirectMainDisplay) / CGDisplayPixelsHigh(kCGDirectMainDisplay);
	NSInteger cols = [MainController numberOfSpacesColumns], rows = [MainController numberOfSpacesRows];
	
	CGFloat cellWidth = [[NSUserDefaults standardUserDefaults] floatForKey:@"PagerCellWidth"];
	
	if (cellWidth < 48) {
		cellWidth = 48;
	}
	
	NSRect currentFrame = _pagerPanel.frame;
	CGFloat newWidth = ((cellWidth + PagerBorderWidth) * cols) + PagerBorderWidth;
	CGFloat newHeight = (((cellWidth / ratio) + PagerBorderWidth) * rows) + PagerBorderWidth;
	CGFloat heightAdjust = (currentFrame.size.height > 0) ? (currentFrame.size.height - newHeight) : 0;
	NSRect pagerFrame = NSMakeRect(currentFrame.origin.x, currentFrame.origin.y + heightAdjust, newWidth, newHeight);
	
	[_pagerPanel setFrame:pagerFrame display:YES animate:animate];
	[_pagerPanel setContentAspectRatio:NSMakeSize(pagerFrame.size.width, pagerFrame.size.height)];
	[_pagerPanel setMinSize:NSMakeSize(cols * 56 + PagerBorderWidth, cols * 56 + PagerBorderWidth)];
	[_pagerPanel setMaxSize:NSMakeSize(cols * 200 + PagerBorderWidth, cols * 200 + PagerBorderWidth)];
}

- (void)_createSpacesLayers
{
	CGFloat ratio = (CGFloat)CGDisplayPixelsWide(kCGDirectMainDisplay) / CGDisplayPixelsHigh(kCGDirectMainDisplay);
	NSSize pagerSize = NSMakeSize(320, 320 / ratio);
	NSInteger cols = [MainController numberOfSpacesColumns], rows = [MainController numberOfSpacesRows];
	//NSSize layerSize = NSMakeSize(pagerSize.width - (cols + 1) * PagerBorderWidth, pagerSize.height - (rows + 1) * PagerBorderWidth);
	CGColorRef backgroundColor = CGColorCreateGenericGray(0.0, 0.4);
	CGColorRef borderColor = CGColorCreateGenericGray(PagerBorderGray, PagerBorderAlpha);
	
	for (NSInteger i = 0; i < rows; i++) {
		for (NSInteger j = 0; j < cols; j++) {
			CALayer *layer = [CALayer layer];
			
			layer.name = [NSString stringWithFormat:@"%d.%d", i, j];
			layer.backgroundColor = backgroundColor;
			layer.borderColor = borderColor;
			layer.delegate = self;
			layer.cornerRadius = 5.0;
			layer.borderWidth = 1.0;
			layer.opacity = 1.0;
			layer.zPosition = [MainController spacesIndexForRow:i + 1 column:j + 1] + 1;
			layer.bounds = CGRectMake(0, 0, (pagerSize.width / cols), (pagerSize.height / rows));
			
			[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintWidth relativeTo:@"superlayer" attribute:kCAConstraintWidth scale:(1.0 / cols) offset:-PagerBorderWidth]];
			[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintHeight relativeTo:@"superlayer" attribute:kCAConstraintHeight scale:(1.0 / rows) offset:-PagerBorderWidth]];
			
			if (i == 0) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY offset:0]];
			} else if (i < rows) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:[NSString stringWithFormat:@"%d.%d", i - 1, j] attribute:kCAConstraintMinY offset:-PagerBorderWidth]];
			}
			
			if (j == 0) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:@"superlayer" attribute:kCAConstraintMinX offset:0]];
			} else if (j < cols) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:[NSString stringWithFormat:@"%d.%d", i, j - 1] attribute:kCAConstraintMaxX offset:PagerBorderWidth]];
			}
			
			[[_layersView layer] addSublayer:layer];
			
			[layer setNeedsDisplay];
		}
	}
	
	CGColorRelease(backgroundColor);
	CGColorRelease(borderColor);
}

- (void)_updateActiveSpace
{
	CGSWorkspace previousSpace = _activeSpace;
	
	CGSGetWorkspace(_CGSDefaultConnection(), &_activeSpace);
	
	for (CALayer *layer in [[_layersView layer] sublayers]) {
		if (layer.zPosition == _activeSpace) {
			CGColorRef color = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
			layer.borderColor = color;
			layer.borderWidth = 2.0;
			CGColorRelease(color);
			
			[layer setNeedsDisplay];
		} else if (layer.zPosition == previousSpace && _activeSpace != previousSpace) {
			CGColorRef borderColor = CGColorCreateGenericGray(PagerBorderGray, PagerBorderAlpha);
			layer.borderColor = borderColor;
			layer.borderWidth = 1.0;
			CGColorRelease(borderColor);
			
			[layer setNeedsDisplay];
		}
	}
	
	CATransition *transition = [CATransition animation];
	transition.duration = 0.5;
	[[_layersView layer] addAnimation:transition forKey:kCATransition];
	
	[[_layersView layer] setNeedsLayout];
}

- (void)_resetTrackingArea
{
	if (_closeTrackingArea) {
		[[_pagerPanel contentView] removeTrackingArea:_closeTrackingArea];
		[_closeTrackingArea release];
	}
	
	_closeTrackingArea = [[NSTrackingArea alloc] initWithRect:[[_pagerPanel contentView] bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways owner:_closeLayer userInfo:nil];
	[[_pagerPanel contentView] addTrackingArea:_closeTrackingArea];
}

- (void)_savePagerDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromPoint([_pagerPanel frame].origin) forKey:@"PagerOrigin"];
	[[NSUserDefaults standardUserDefaults] setFloat:((CALayer *)[[[_layersView layer] sublayers] lastObject]).bounds.size.width forKey:@"PagerCellWidth"];
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
