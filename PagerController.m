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
#import "CGSPrivate.h"
#import "CloseButtonLayer.h"

extern OSStatus CGContextCopyWindowCaptureContentsToRect(CGContextRef ctx, CGRect rect, NSInteger cid, CGWindowID wid, NSInteger flags);

static const CGFloat PagerBorderGray = 0.2;
static const CGFloat PagerBorderAlpha = 0.6;

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
		/*NSBezierPath *framePath = [NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(layer.bounds) xRadius:12 yRadius:12];
		
		[NSBezierPath setDefaultLineWidth:5.0];
		
		[[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] set];
		[framePath fill];
		
		//Draw the glassy gradient
		NSRect glassRect = NSRectFromCGRect(CGRectInset(layer.bounds, -5, -5));
		glassRect.origin.y += glassRect.size.height * .65;
		glassRect.size.height *= .35;
		
		NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.70 alpha:1.0] endingColor:[NSColor blackColor]];
		NSBezierPath *glassPath = [NSBezierPath bezierPathWithRoundedRect:glassRect xRadius:20 yRadius:20];
		
		[framePath setClip];
		[gradient drawInBezierPath:glassPath angle:270];
		[gradient release];*/
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(layer.bounds) xRadius:12 yRadius:12];
		
		[NSBezierPath setDefaultLineWidth:0.5];
		
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.9] set];
		[borderPath fill];
		
		[[NSColor colorWithCalibratedWhite:PagerBorderGray alpha:PagerBorderAlpha] set];
		[borderPath stroke];
		
		//Draw clear in each of the spaces
		for (CALayer *layer in [[_layersView layer] sublayers]) {
			CGRect frame = [layer convertRect:layer.frame toLayer:layer];
			frame.origin.x += 8;
			
			//Clear the area of each space
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeClear];
			[[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] set];
			[[NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(frame) xRadius:6 yRadius:6] fill];
		}
	} else {
		NSInteger workspace = layer.zPosition;
		NSInteger currentSpace = 0;
		
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
	
	NSRect layersRect = NSInsetRect([[_pagerPanel contentView] bounds], 8, 8);
	layersRect.origin.y -= 8;
	layersRect.size.width += 8;
	layersRect.size.height += 8;
	
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
	resizeLayer.frame = CGRectMake(_pagerPanel.frame.size.width - 12, 4, 8, 8);
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
	CGFloat newWidth = ((cellWidth + 8) * cols) + 8;
	CGFloat newHeight = (((cellWidth / ratio) + 8) * rows) + 8;
	CGFloat heightAdjust = (currentFrame.size.height > 0) ? (currentFrame.size.height - newHeight) : 0;
	NSRect pagerFrame = NSMakeRect(currentFrame.origin.x, currentFrame.origin.y + heightAdjust, newWidth, newHeight);
	
	[_pagerPanel setFrame:pagerFrame display:YES animate:animate];
	[_pagerPanel setContentAspectRatio:NSMakeSize(pagerFrame.size.width, pagerFrame.size.height)];
	[_pagerPanel setMinSize:NSMakeSize(cols * 56 + 8, cols * 56 + 8)];
	[_pagerPanel setMaxSize:NSMakeSize(cols * 200 + 8, cols * 200 + 8)];
}

- (void)_createSpacesLayers
{
	CGFloat ratio = (CGFloat)CGDisplayPixelsWide(kCGDirectMainDisplay) / CGDisplayPixelsHigh(kCGDirectMainDisplay);
	NSSize pagerSize = NSMakeSize(320, 320 / ratio);
	NSInteger cols = [MainController numberOfSpacesColumns], rows = [MainController numberOfSpacesRows];
	//NSSize layerSize = NSMakeSize(pagerSize.width - (cols + 1) * 8, pagerSize.height - (rows + 1) * 8);
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
			layer.masksToBounds = YES;
			layer.opacity = 1.0;
			layer.zPosition = [MainController spacesIndexForRow:i + 1 column:j + 1] + 1;
			layer.bounds = CGRectMake(0, 0, (pagerSize.width / cols), (pagerSize.height / rows));
			
			[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintWidth relativeTo:@"superlayer" attribute:kCAConstraintWidth scale:(1.0 / cols) offset:-8]];
			[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintHeight relativeTo:@"superlayer" attribute:kCAConstraintHeight scale:(1.0 / rows) offset:-8]];
			
			if (i == 0) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY offset:0]];
			} else if (i < rows) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:[NSString stringWithFormat:@"%d.%d", i - 1, j] attribute:kCAConstraintMinY offset:-8]];
			}
			
			if (j == 0) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:@"superlayer" attribute:kCAConstraintMinX offset:0]];
			} else if (j < cols) {
				[layer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:[NSString stringWithFormat:@"%d.%d", i, j - 1] attribute:kCAConstraintMaxX offset:8]];
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
	NSInteger previousSpace = _activeSpace;
	
	CGSGetWorkspace(_CGSDefaultConnection(), &_activeSpace);
	
	CGColorRef borderColor = CGColorCreateGenericGray(PagerBorderGray, PagerBorderAlpha);
	
	for (CALayer *layer in [[_layersView layer] sublayers]) {
		if (layer.zPosition == _activeSpace) {
			CGColorRef color = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
			layer.borderColor = color;
			layer.borderWidth = 2.0;
			CGColorRelease(color);
			
			[layer setNeedsDisplay];
		} else if (layer.zPosition == previousSpace && _activeSpace != previousSpace) {
			layer.borderColor = borderColor;
			layer.borderWidth = 1.0;
			
			[layer setNeedsDisplay];
		}
	}
	
	CATransition *transition = [CATransition animation];
	transition.duration = 0.5;
	[[_layersView layer] addAnimation:transition forKey:kCATransition];
	
	CGColorRelease(borderColor);
	
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
