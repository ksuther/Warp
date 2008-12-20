//
//  MainController.m
//  Edger
//
//  Created by Kent Sutherland on 11/1/07.
//  Copyright 2007-2008 Kent Sutherland. All rights reserved.
//

#import "MainController.h"
#import "WarpEdgeWindow.h"
#import "CGSPrivate.h"
#import "ScreenSaver.h"
#import "PagerController.h"

static const int WarpCornerPadding = 30;

NSString *SwitchSpacesNotification = @"com.apple.switchSpaces";
float _activationDelay;
NSUInteger _activationModifiers;
BOOL _warpMouse, _wraparound;
Edge *_hEdges = nil, *_vEdges = nil;
CGRect _totalScreenRect;
WarpEdgeWindow *_edgeWindow = nil;
NSTimer *_warpTimer = nil;

BOOL _timeMachineActive = NO;

BOOL equalEdges(Edge *edge1, Edge *edge2)
{
	return (edge1 == edge2) || (edge1 && edge2 &&
			(edge1->point == edge2->point) &&
			(WarpEqualRanges(edge1->range, edge2->range)) &&
			(edge1->isLeftOrTop == edge2->isLeftOrTop) &&
			(edge1->isDockOrMenubar == edge2->isDockOrMenubar));
}

Edge * edgeForValue(Edge *edge, CGFloat value) {
	while (edge) {
		if (edge->point == value) {
			return edge;
		}
		edge = edge->next;
	}
	
	return nil;
}

Edge * edgeForValueInRange(Edge *edge, CGFloat value, float rangeValue) {
	Edge *result;
	
	if ( (result = edgeForValue(edge, value)) && WarpLocationInRange(rangeValue, result->range)) {
		return result;
	}
	
	return nil;
}

Edge * removeEdge(Edge *edgeList, Edge *edge) {
	if (edge == edgeList) {
		edgeList = edge->next;
	} else {
		while (edgeList->next != edge) {
			edgeList = edgeList->next;
		}
		edgeList->next = edge->next;
	}
	
	free(edge);
	
	return edgeList;
}

Edge * addEdge(Edge *edgeList, CGFloat point, BOOL isLeftOrTop, BOOL isDockOrMenubar, WarpRange range, NSScreen *screen) {
	range.location += 40;
	range.length -= 80;
	
	Edge *edge = malloc(sizeof(Edge));
	edge->point = point;
	edge->isLeftOrTop = isLeftOrTop;
	edge->isDockOrMenubar = isDockOrMenubar;
	edge->next = nil;
	edge->range = range;
	edge->screen = screen;
	
	if (edgeList == nil) {
		edgeList = edge;
	} else {
		Edge *lastEdge = edgeList;
		while (lastEdge->next) {
			lastEdge = lastEdge->next;
		}
		lastEdge->next = edge;
	}
	
	return edgeList;
}

Edge * addEdgeWithoutOverlap(Edge *edgeList, CGFloat point, BOOL isLeftOrTop, BOOL isDockOrMenubar, WarpRange range, NSScreen *screen, Edge *existingEdge) {
	//
	//Add edges to cover the non-overlapping sections
	//5 cases: range < existingRange, range > existingRange, range < and > existingRange, range == existingRange, range not in existingRange
	//Precondition: range != existingRange
	//
	WarpRange *existingRange = &existingEdge->range;
	
	if (existingRange->location < range.location && WarpMaxRange(*existingRange) > WarpMaxRange(range)) {
		edgeList = removeEdge(edgeList, existingEdge);
	} else if (existingRange->location < range.location) {
		CGFloat delta = WarpMaxRange(*existingRange) - range.location;
		range.location += delta;
		range.length -= delta;
		existingRange->length -= delta;
	} else if (existingRange->location > range.location) {
		CGFloat delta = WarpMaxRange(range) - existingRange->location;
		range.length -= delta;
		existingRange->location += delta;
		existingRange->length -= delta;
	}
	
	return addEdge(edgeList, point, isLeftOrTop, isDockOrMenubar, range, screen);
}

OSStatus mouseMovedHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
	HIPoint mouseLocation;
	NSInteger direction = -1;
	
	HIGetMousePosition(kHICoordSpaceScreenPixel, NULL, &mouseLocation);
	
	Edge *edge;
	
	if ( (edge = edgeForValueInRange(_hEdges, mouseLocation.x, mouseLocation.y)) ) {
		direction = edge->isLeftOrTop ? LeftDirection : RightDirection;
	} else if ( (edge = edgeForValueInRange(_vEdges, mouseLocation.y, mouseLocation.x)) ) {
		direction = edge->isLeftOrTop ? UpDirection : DownDirection;
	}
	
	if (direction != -1) {
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:direction], @"Direction", [NSValue valueWithPointer:edge], @"Edge", nil];
		
		if ([[[_warpTimer userInfo] objectForKey:@"Edge"] pointerValue] != edge) {
			[_warpTimer invalidate];
			_warpTimer = [NSTimer scheduledTimerWithTimeInterval:_activationDelay target:[MainController class] selector:@selector(timerFired:) userInfo:info repeats:NO];
		}
	}
	
	return CallNextEventHandler(nextHandler, theEvent);
}

void spacesSwitchCallback(int data1, int data2, int data3, void *userParameter) {
	NSInteger currentSpace = 0;
	
	if (CGSGetWorkspace(_CGSDefaultConnection(), &currentSpace) == kCGErrorSuccess && currentSpace != 65538) {
		NSDictionary *info = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:currentSpace] forKey:@"Space"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ActiveSpaceDidSwitchNotification" object:nil userInfo:info];
	}
}

void spacesChangedCallback(int data1, int data2, int data3, void *userParameter) {
	static NSInteger lastCols;
	static NSInteger lastRows;
	NSInteger currentCols = [MainController numberOfSpacesColumns];
	NSInteger currentRows = [MainController numberOfSpacesRows];
	
	//The callback seems to get called 4 times every time the number of spaces changes
	//This ensures only one notification gets fired
	if (lastCols != currentCols || lastRows != currentRows) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SpacesConfigurationDidChangeNotification" object:nil userInfo:nil];
	}
	
	lastCols = currentCols;
	lastRows = currentRows;
}

static OSStatus hotKeyEventHandler(EventHandlerCallRef inHandlerRef, EventRef inEvent, void *refCon)
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PagerHotKeyPressed" object:nil];
	
	return noErr;
}

@interface MainController (Private)
- (void)_registerCarbonEventHandlers;
- (void)_unregisterCarbonEventHandlers;
- (void)_registerHotKeyEventHandlers;
- (void)_registerHotKey;
- (void)_unregisterHotKey;
@end

@implementation MainController

+ (NSInteger)numberOfSpacesRows
{
	CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
	
	NSInteger rowCount = CFPreferencesGetAppIntegerValue(CFSTR("workspaces-rows"), CFSTR("com.apple.dock"), nil);
	if (rowCount == 0) {
		rowCount = 2;
	}
	
	return rowCount;
}

+ (NSInteger)numberOfSpacesColumns
{
	CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
	
	NSInteger columnCount = CFPreferencesGetAppIntegerValue(CFSTR("workspaces-cols"), CFSTR("com.apple.dock"), nil);
	if (columnCount == 0) {
		columnCount = 2;
	}
	
	return columnCount;
}

+ (int)dockSide
{
	CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
	
	NSString *orientation = [(id)CFPreferencesCopyAppValue(CFSTR("orientation"), CFSTR("com.apple.dock")) autorelease];
	
	if ([orientation isEqualToString:@"left"]) {
		return LeftDirection; 
	} else if ([orientation isEqualToString:@"right"]) {
		return RightDirection;
	} else if ([orientation isEqualToString:@"top"]) {
		return UpDirection;
	} else {
		return DownDirection;
	} 
}

+ (BOOL)requiredModifiersDown
{
	return _activationModifiers == 0 || (GetCurrentKeyModifiers() & _activationModifiers) == _activationModifiers;
}

+ (BOOL)isSecurityAgentActive
{
	ProcessSerialNumber psn;
	BOOL active = NO;
	
	if (GetFrontProcess(&psn) == noErr) {
		CFStringRef name;
		CopyProcessName(&psn, &name);
		active = [(NSString *)name isEqualToString:@"SecurityAgent"];
		[(NSString *)name release];
	}
	
	return active;
}

+ (NSInteger)getCurrentSpaceIndex
{
	NSInteger currentSpace;
	
	if (CGSGetWorkspace(_CGSDefaultConnection(), &currentSpace) == kCGErrorSuccess) {
		if (currentSpace == 65538) {
			return -1;
		}
		
		return currentSpace;
	} else {
		return -1;
	}
}

+ (NSInteger)getCurrentSpaceRow:(NSInteger *)row column:(NSInteger *)column
{
	NSInteger currentSpace;
	
	if (CGSGetWorkspace(_CGSDefaultConnection(), &currentSpace) == kCGErrorSuccess) {
		if (currentSpace == 65538) {
			return -1;
		}
		
		//Figure out the current row and column based on the number of rows and columns
		NSInteger cols = [self numberOfSpacesColumns];
		
		*row = ((currentSpace - 1) / cols) + 1;
		*column = currentSpace % cols;
		
		if (*column == 0) {
			*column = cols;
		}
		
		return 0;
	} else {
		return -1;
	}
}

+ (NSPoint)getSpaceInDirection:(NSUInteger)direction row:(NSInteger)row column:(NSInteger)col
{
	NSInteger rows = [MainController numberOfSpacesRows];
	NSInteger cols = [MainController numberOfSpacesColumns];
	
	switch (direction) {
		case LeftDirection:
			if (_wraparound && col == 1 && cols > 1) {
				//Wrap to the rightmost space
				col = cols + 1;
			}
			
			col--;
			break;
		case RightDirection:
			if (_wraparound && col == cols && cols > 1) {
				//Wrap to the leftmost space
				col = 0;
			}
			
			col++;
			break;
		case DownDirection:
			if (_wraparound && row == rows && rows > 1) {
				//Wrap to the top space
				row = 0;
			}
			
			row++;
			break;
		case UpDirection:
			if (_wraparound && row == 1 && rows > 1) {
				//Wrap to the lowest space
				row = rows + 1;
			}
			
			row--;
			break;
	}
	
	return NSMakePoint(col, row);
}

+ (NSPoint)getSpaceInDirection:(NSUInteger)direction
{
	
	NSInteger row, col;
	
	if ([MainController getCurrentSpaceRow:&row column:&col] == -1) {
		return NSMakePoint(-1, -1);
	}
	
	return [self getSpaceInDirection:direction row:row column:col];
}

+ (NSInteger)spacesIndexForRow:(NSInteger)row column:(NSInteger)column
{
	NSInteger rows = [self numberOfSpacesRows];
	NSInteger cols = [self numberOfSpacesColumns];
	NSInteger targetSpace = ((row - 1) * cols) + column - 1;
	
	return (row <= rows && column <= cols && row > 0 && column > 0 && targetSpace >= 0 && targetSpace < rows * cols) ? targetSpace : -1;
}

+ (void)timerFired:(NSTimer *)timer
{
	NSUInteger direction = [[[timer userInfo] objectForKey:@"Direction"] unsignedIntValue];
	Edge *edge = [[[timer userInfo] objectForKey:@"Edge"] pointerValue];
	BOOL onEdge = NO;
	CGPoint mouseLocation;
	
	HIGetMousePosition(kHICoordSpaceScreenPixel, NULL, &mouseLocation);
	
	if (direction == UpDirection || direction == DownDirection) {
		onEdge = edge->point == mouseLocation.y;
	} else {
		onEdge = edge->point == mouseLocation.x;
	}
	
	if (onEdge && [self requiredModifiersDown]) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ClickToWarp"] &&
				!([[NSUserDefaults standardUserDefaults] boolForKey:@"DisableForMenubarDock"] && edge->isDockOrMenubar)) {
			NSPoint spacePoint = [self getSpaceInDirection:direction];
			NSInteger spacesIndex = [self spacesIndexForRow:spacePoint.y column:spacePoint.x];
			
			if (spacesIndex > -1 &&
					(!_edgeWindow || ![_edgeWindow isVisible] || !equalEdges([_edgeWindow edge], edge))) {
				[_edgeWindow orderOut:nil];
				[_edgeWindow release];
				
				if (NSPointInRect([NSEvent mouseLocation], [WarpEdgeWindow frameForEdge:edge direction:direction])) {
					_edgeWindow = [[WarpEdgeWindow windowWithEdge:edge workspace:spacesIndex direction:direction] retain];
					[_edgeWindow orderFront:nil];
				} else {
					_edgeWindow = nil;
				}
			}
		} else {
			[MainController warpInDirection:direction edge:edge];
		}
	}
	
	_warpTimer = nil;
}

+ (void)warpInDirection:(NSUInteger)direction edge:(Edge *)edge
{
	if (!_timeMachineActive && ![self isSecurityAgentActive]) {
		CGPoint mouseLocation, warpLocation;
		NSInteger row, col;
		BOOL switchedSpace = NO;
		NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
		
		HIGetMousePosition(kHICoordSpaceScreenPixel, NULL, &mouseLocation);
		
		if ([df boolForKey:@"ClickToWarp"] && _edgeWindow) {
			if (direction == LeftDirection || direction == RightDirection) {
				mouseLocation.x = [_edgeWindow edge]->point;
			} else {
				mouseLocation.y = [_edgeWindow edge]->point;
			}
		}
		
		NSPoint newSpace = [self getSpaceInDirection:direction];
		row = newSpace.y;
		col = newSpace.x;
		
		BOOL validEdgeDirection = edge->isLeftOrTop;
		
		if (direction == RightDirection || direction == DownDirection) {
			validEdgeDirection = !validEdgeDirection;
		}
		
		if (edge && validEdgeDirection && !([df boolForKey:@"DisableForMenubarDock"] && edge->isDockOrMenubar)) {
			switchedSpace = [MainController switchToSpaceRow:row column:col];
		}
		
		if (switchedSpace) {
			switch (direction) {
				case LeftDirection:
					warpLocation.x = _totalScreenRect.origin.x + _totalScreenRect.size.width - WarpCornerPadding;
					warpLocation.y = mouseLocation.y;
					mouseLocation.x += 3;
					break;
				case RightDirection:
					warpLocation.x = _totalScreenRect.origin.x + WarpCornerPadding;
					warpLocation.y = mouseLocation.y;
					mouseLocation.x -= 3;
					break;
				case DownDirection:
					warpLocation.x = mouseLocation.x;
					warpLocation.y = _totalScreenRect.origin.y + WarpCornerPadding;
					mouseLocation.y -= 3;
					break;
				case UpDirection:
					warpLocation.x = mouseLocation.x;
					warpLocation.y = _totalScreenRect.origin.y + _totalScreenRect.size.height - WarpCornerPadding;
					mouseLocation.y += 3;
					break;
			}
			
			if (_warpMouse || ![df boolForKey:@"ClickToWarp"]) {
				CGWarpMouseCursorPosition(_warpMouse ? warpLocation : mouseLocation);
			}
			
			if ([df boolForKey:@"ClickToWarp"]) {
				//Determine if the click-to-warp floating window should be hidden
				NSPoint nextSpace = [self getSpaceInDirection:direction row:row column:col];
				
				if ([self spacesIndexForRow:nextSpace.y column:nextSpace.x] == -1) {
					[_edgeWindow orderOut:nil];
					[_edgeWindow release];
					_edgeWindow = nil;
				}
			}
		}
	}
}

+ (BOOL)switchToSpaceRow:(NSInteger)row column:(NSInteger)column
{
	NSInteger targetSpace;
	
	if ((targetSpace = [self spacesIndexForRow:row column:column]) > -1) {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:SwitchSpacesNotification object:[NSString stringWithFormat:@"%d", targetSpace]];
		return YES;
	}
	
	return NO;
}

+ (BOOL)switchToSpaceIndex:(NSInteger)index
{
	NSInteger currentSpace;
	
	if (CGSGetWorkspace(_CGSDefaultConnection(), &currentSpace) == kCGErrorSuccess && currentSpace != index + 1) {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:SwitchSpacesNotification object:[NSString stringWithFormat:@"%d", index]];
		return YES;
	}
	
	return NO;
}

- (id)init
{
	if ( (self = [super init]) ) {
		_pagerController = [[PagerController alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_pagerController release];
	[_cachedVersion release];
	
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
	[self _registerHotKeyEventHandlers];
	[self _registerCarbonEventHandlers];
	
	//Register for Spaces switch notifications - http://tonyarnold.com/entries/detecting-when-the-active-space-changes-under-leopard/
	CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spacesSwitchCallback, CGSWorkspaceChangedEvent, (void *)self);
	CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spacesChangedCallback, CGSWorkspaceConfigurationEnabledEvent, (void *)self);
	CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spacesChangedCallback, CGSWorkspaceConfigurationDisabledEvent, (void *)self);
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:NSApp selector:@selector(terminate:) name:@"TerminateWarpNotification" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(versionRequested:) name:@"WarpVersionRequest" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:@"WarpDefaultsChanged" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenParametersChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
	
	[self performSelector:@selector(defaultsChanged:)];
	[self updateWarpRects];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(timeMachineNotification:) name:@"com.apple.backup.BackupTargetActivatedNotification" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(timeMachineNotification:) name:@"com.apple.backup.BackupDismissedNotification" object:nil];
	
	_cachedVersion = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] copy];
}

- (void)applicationWillTerminate:(NSNotification *)note
{
	[self _unregisterCarbonEventHandlers];
	
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:NSApp name:@"TerminateWarpNotification" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WarpDefaultsChanged" object:nil];
}

- (void)timeMachineNotification:(NSNotification *)note
{
	_timeMachineActive = [[note name] isEqualToString:@"com.apple.backup.BackupTargetActivatedNotification"];
}

- (void)versionRequested:(NSNotification *)note
{
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"WarpVersionResponse" object:_cachedVersion];
}

- (void)defaultsChanged:(NSNotification *)note
{
	NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
	
	[df synchronize];
	
	_activationDelay = [df floatForKey:@"Delay"];
	
	id command = [df objectForKey:@"CommandModifier"];
	id option = [df objectForKey:@"OptionModifier"];
	id control = [df objectForKey:@"ControlModifier"];
	id shift = [df objectForKey:@"ShiftModifier"];
	
	_activationModifiers = 0;
	
	if ([command boolValue]) {
		_activationModifiers |= cmdKey;
	}
	
	if ([option boolValue]) {
		_activationModifiers |= optionKey;
	}
	
	if ([control boolValue]) {
		_activationModifiers |= controlKey;
	}
	
	if ([shift boolValue]) {
		_activationModifiers |= shiftKey;
	}
	
	_warpMouse = [df boolForKey:@"WarpMouse"];
	_wraparound = [df boolForKey:@"Wraparound"];
	
	[self _registerCarbonEventHandlers];
	[self _registerHotKey];
}

- (void)screenParametersChanged:(NSNotification *)note
{
	[self performSelector:@selector(updateWarpRects) withObject:nil afterDelay:1.0];
}

- (void)updateWarpRects
{
	CGDisplayCount count;
	CGDirectDisplayID *displays;
	CGGetActiveDisplayList(0, NULL, &count);
	displays = calloc(count, sizeof(displays[0]));
	
	Edge *edge = _hEdges, *prev;
	
	//Free horizontal edges
	while (edge) {
		prev = edge;
		edge = edge->next;
		free(prev);
	}
	
	//Free vertical edges
	edge = _vEdges;
	
	while (edge) {
		prev = edge;
		edge = edge->next;
		free(prev);
	}
	
	_totalScreenRect = CGRectNull;
	_hEdges = nil;
	_vEdges = nil;
	
	if (displays && count > 0) {
		CGGetActiveDisplayList(count, displays, &count);
		CGRect bounds;
		CGFloat point;
		NSArray *screens = [NSScreen screens];
		
		#ifdef TEST_BOUNDS
			CGRect testDisplays[2];
			testDisplays[0] = CGRectMake(0, 0, 1600, 1200);
			testDisplays[1] = CGRectMake(1200, -768, 1024, 768);
			count = 2;
		#endif
		
		for (NSUInteger i = 0; i < count; i++) {
			NSScreen *currentScreen = nil;
			
			#ifdef TEST_BOUNDS
				bounds = testDisplays[i];
				NSLog(@"bounds: %@", NSStringFromRect(*(NSRect *)&bounds));
			#else
				bounds = CGDisplayBounds(displays[i]);
			#endif
			
			int dockScreenSide = -1; //Set to true if the dock is on this screen
			
			for (NSScreen *screen in screens) {
				if ((CGDirectDisplayID)[[[screen deviceDescription] objectForKey:@"NSScreenNumber"] longValue] == displays[i]) {
					int dockOrientation = [MainController dockSide];
					
					if (dockOrientation == DownDirection || dockOrientation == UpDirection) {
						float menubarHeight = 0;
						
						if ([NSMenu menuBarVisible]) {
							menubarHeight = [[NSApp mainMenu] menuBarHeight];
						}
						
						float heightWithoutMenBar = [screen frame].size.height - menubarHeight;
						if ([screen visibleFrame].size.height < heightWithoutMenBar) {
							dockScreenSide = dockOrientation;
						}
					} else if ([screen visibleFrame].size.width < [screen frame].size.width) {
						dockScreenSide = dockOrientation;
					}
					
					currentScreen = screen;
					break;
				}
			}
			
			//Left edge
			if ( (edge = edgeForValue(_hEdges, bounds.origin.x)) || (edge = edgeForValue(_hEdges, bounds.origin.x - 1)) || (edge = edgeForValue(_hEdges, bounds.origin.x + 1)) ) {
				if (edge->isLeftOrTop) {
					edge->range.length += bounds.size.height;
					
					if (edge->range.location > bounds.origin.y) {
						edge->range.location -= bounds.size.height;
					}
				} else {
					if (edge->range.location == bounds.origin.y && edge->range.length == bounds.size.height) {
						_hEdges = removeEdge(_hEdges, edge);
					} else {
						_hEdges = addEdgeWithoutOverlap(_hEdges, bounds.origin.x, YES, NO, WarpMakeRange(bounds.origin.y, bounds.size.height), currentScreen, edge);
					}
				}
			} else {
				_hEdges = addEdge(_hEdges, bounds.origin.x, YES, (dockScreenSide == LeftDirection), WarpMakeRange(bounds.origin.y, bounds.size.height), currentScreen);
			}
			
			//Right edge
			point = bounds.origin.x + bounds.size.width - 1;
			if ( (edge = edgeForValue(_hEdges, bounds.origin.x + bounds.size.width)) || (edge = edgeForValue(_hEdges, bounds.origin.x + bounds.size.width - 1)) || (edge = edgeForValue(_hEdges, bounds.origin.x + bounds.size.width + 1)) ) {
				if (!edge->isLeftOrTop) {
					edge->range.length += bounds.size.height;
					
					if (edge->range.location > bounds.origin.y) {
						edge->range.location -= bounds.size.height;
					}
				} else {
					if (edge->range.location == bounds.origin.y && edge->range.length == bounds.size.height) {
						_hEdges = removeEdge(_hEdges, edge);
					} else {
						_hEdges = addEdgeWithoutOverlap(_hEdges, point, NO, NO, WarpMakeRange(bounds.origin.y, bounds.size.height), currentScreen, edge);
					}
				}
			} else {
				_hEdges = addEdge(_hEdges, point, NO, (dockScreenSide == RightDirection), WarpMakeRange(bounds.origin.y, bounds.size.height), currentScreen);
			}
			
			//Top edge
			if ( (edge = edgeForValue(_vEdges, bounds.origin.y)) || (edge = edgeForValue(_vEdges, bounds.origin.y - 1)) || (edge = edgeForValue(_vEdges, bounds.origin.y + 1)) ) {
				if (edge->isLeftOrTop) {
					edge->range.length += bounds.size.width;
					
					if (edge->range.location > bounds.origin.x) {
						edge->range.location -= bounds.size.width;
					}
				} else {
					if (edge->range.location == bounds.origin.x && edge->range.length == bounds.size.width) {
						_vEdges = removeEdge(_vEdges, edge);
					} else {
						_vEdges = addEdgeWithoutOverlap(_vEdges, bounds.origin.y, YES, NO, WarpMakeRange(bounds.origin.x, bounds.size.width), currentScreen, edge);
					}
				}
			} else {
				_vEdges = addEdge(_vEdges, bounds.origin.y, YES, (i == 0 || dockScreenSide == UpDirection), WarpMakeRange(bounds.origin.x, bounds.size.width), currentScreen);
			}
			
			//Bottom edge
			point = bounds.origin.y + bounds.size.height - 1;
			if ( (edge = edgeForValue(_vEdges, bounds.origin.y + bounds.size.height)) || (edge = edgeForValue(_vEdges, bounds.origin.y + bounds.size.height - 1)) || (edge = edgeForValue(_vEdges, bounds.origin.y + bounds.size.height + 1)) ) {
				if (!edge->isLeftOrTop) {
					edge->range.length += bounds.size.width;
					
					if (edge->range.location > bounds.origin.x) {
						edge->range.location -= bounds.size.width;
					}
				} else {
					if (edge->range.location == bounds.origin.x && edge->range.length == bounds.size.width) {
						_vEdges = removeEdge(_vEdges, edge);
					} else {
						_vEdges = addEdgeWithoutOverlap(_vEdges, point, NO, (dockScreenSide == DownDirection), WarpMakeRange(bounds.origin.x, bounds.size.width), currentScreen, edge);
					}
				}
			} else {
				_vEdges = addEdge(_vEdges, point, NO, (dockScreenSide == DownDirection), WarpMakeRange(bounds.origin.x, bounds.size.width), currentScreen);
			}
			
			_totalScreenRect = CGRectUnion(_totalScreenRect, bounds);
		}
	}
	
	//Log found edges
	#ifdef TEST_BOUNDS
	edge = _hEdges;
	while (edge != nil) {
		NSLog(@"horizontal edge: %f isLeftOrTop: %d {%f %f}", edge->point, edge->isLeftOrTop, edge->range.location, edge->range.length);
		edge = edge->next;
	}
	edge = _vEdges;
	while (edge != nil) {
		NSLog(@"vertical edge: %f isLeftOrTop: %d {%f %f}", edge->point, edge->isLeftOrTop, edge->range.location, edge->range.length);
		edge = edge->next;
	}
	#endif
	
	free(displays);
}

#pragma mark -
#pragma mark Private

- (void)_registerCarbonEventHandlers
{
	[self _unregisterCarbonEventHandlers];
	
	mouseMovedHandlerUPP = NewEventHandlerUPP(mouseMovedHandler);
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ClickToWarp"]) {
		EventTypeSpec eventType[1];
		eventType[0].eventClass = kEventClassMouse;
		eventType[0].eventKind = kEventMouseMoved;
		
		InstallEventHandler(GetEventMonitorTarget(), mouseMovedHandlerUPP, 1, eventType, nil, &mouseHandler);
	} else {
		EventTypeSpec eventType[2];
		eventType[0].eventClass = kEventClassMouse;
		eventType[0].eventKind = kEventMouseMoved;
		eventType[1].eventClass = kEventClassMouse;
		eventType[1].eventKind = kEventMouseDragged;
		
		InstallEventHandler(GetEventMonitorTarget(), mouseMovedHandlerUPP, 2, eventType, nil, &mouseHandler);
	}
}

- (void)_unregisterCarbonEventHandlers
{
	if (mouseHandler) {
		RemoveEventHandler(mouseHandler);
		DisposeEventHandlerUPP(mouseMovedHandlerUPP);
	}
}

- (void)_registerHotKeyEventHandlers
{
	EventTypeSpec eventSpec[1] = {
		{kEventClassKeyboard, kEventHotKeyPressed},
	};
	
	InstallApplicationEventHandler(&hotKeyEventHandler, 1, eventSpec, NULL, &hotKeyHandlerRef);
}

- (void)_registerHotKey
{
	short code = [[NSUserDefaults standardUserDefaults] integerForKey:@"PagerKeyCode"];
	unsigned int modifiers = [[NSUserDefaults standardUserDefaults] integerForKey:@"PagerModifierFlags"];
	
	if (code != 0 && (!hotKeyRef || _activeKeyCode != code || _activeModifiers != modifiers)) {
		EventHotKeyID hotKeyID;
		hotKeyID.signature = 'Page';
		hotKeyID.id = (long)code;
		
		[self _unregisterHotKey];
		
		RegisterEventHotKey(code, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef);
		
		_activeKeyCode = code;
		_activeModifiers = modifiers;
	}
}

- (void)_unregisterHotKey
{
	if (hotKeyRef) {
		UnregisterEventHotKey(hotKeyRef);
		hotKeyRef = nil;
	}
}

@end
