//
//  MainController.m
//  Edger
//
//  Created by Kent Sutherland on 11/1/07.
//  Copyright 2007-2008 Kent Sutherland. All rights reserved.
//

#import "MainController.h"
#import "CoreGraphicsPrivate.h"

NSString *SwitchSpacesNotification = @"com.apple.switchSpaces";
float _activationDelay;
NSUInteger _activationModifiers;
BOOL _warpMouse, _wraparound;
Edge *_hEdges = nil, *_vEdges = nil;
CGRect _totalScreenRect;

BOOL _timeMachineActive = NO;

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

Edge * addEdge(Edge *edgeList, CGFloat point, BOOL isLeftOrTop, WarpRange range) {
	range.location += 40;
	range.length -= 80;
	
	Edge *edge = malloc(sizeof(Edge));
	edge->point = point;
	edge->isLeftOrTop = isLeftOrTop;
	edge->next = nil;
	edge->range = range;
	
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

Edge * addEdgeWithoutOverlap(Edge *edgeList, CGFloat point, BOOL isLeftOrTop, WarpRange range, Edge *existingEdge) {
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
	
	return addEdge(edgeList, point, isLeftOrTop, range);
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
		NSDictionary *info = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:direction] forKey:@"Direction"];
		[NSTimer scheduledTimerWithTimeInterval:_activationDelay target:[MainController class] selector:@selector(switchToSpace:) userInfo:info repeats:NO];
	}
	
	return CallNextEventHandler(nextHandler, theEvent);
}

@implementation MainController

+ (NSInteger)numberOfSpacesRows
{
	CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
	
	int rowCount = CFPreferencesGetAppIntegerValue(CFSTR("workspaces-rows"), CFSTR("com.apple.dock"), nil);
	if (rowCount == 0) {
		rowCount = 2;
	}
	
	return rowCount;
}

+ (NSInteger)numberOfSpacesColumns
{
	CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
	
	int columnCount = CFPreferencesGetAppIntegerValue(CFSTR("workspaces-cols"), CFSTR("com.apple.dock"), nil);
	if (columnCount == 0) {
		columnCount = 2;
	}
	
	return columnCount;
}

+ (NSInteger)getCurrentSpaceRow:(NSInteger *)row column:(NSInteger *)column
{
	NSInteger currentSpace = 0;
	if (CGSGetWorkspace(_CGSDefaultConnection(), &currentSpace) == kCGErrorSuccess) {
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

+ (void)switchToSpace:(NSTimer *)timer
{
	if (!_timeMachineActive && (_activationModifiers == 0 || (GetCurrentKeyModifiers() & _activationModifiers) == _activationModifiers)) {
		NSDictionary *info = [timer userInfo];
		CGPoint mouseLocation, warpLocation;
		int row, col;
		BOOL switchedSpace = NO;
		Edge *edge = nil;
		
		HIGetMousePosition(kHICoordSpaceScreenPixel, NULL, &mouseLocation);
		
		[MainController getCurrentSpaceRow:&row column:&col];
		
		switch ([[info objectForKey:@"Direction"] intValue]) {
			case LeftDirection:
				if (_wraparound && col == 1) {
					//Wrap to the rightmost space
					col = [MainController numberOfSpacesColumns] + 1;
				}
				
				if ((edge = edgeForValueInRange(_hEdges, mouseLocation.x, mouseLocation.y)) && edge->isLeftOrTop && col > 1) {
					switchedSpace = [MainController switchToSpaceRow:row column:col - 1];
					
					warpLocation.x = _totalScreenRect.origin.x + _totalScreenRect.size.width - 20;
					warpLocation.y = mouseLocation.y;
					mouseLocation.x += 3;
				}
				break;
			case RightDirection:
				if (_wraparound && col == [MainController numberOfSpacesColumns]) {
					//Wrap to the leftmost space
					col = 0;
				}
				
				if ((edge = edgeForValueInRange(_hEdges, mouseLocation.x, mouseLocation.y)) && !edge->isLeftOrTop && col < [MainController numberOfSpacesColumns]) {
					switchedSpace = [MainController switchToSpaceRow:row column:col + 1];
					
					warpLocation.x = _totalScreenRect.origin.x + 20;
					warpLocation.y = mouseLocation.y;
					mouseLocation.x -= 3;
				}
				break;
			case DownDirection:
				if (_wraparound && row == [MainController numberOfSpacesRows]) {
					//Wrap to the top space
					row = 0;
				}
				
				if ((edge = edgeForValueInRange(_vEdges, mouseLocation.y, mouseLocation.x)) && !edge->isLeftOrTop && row < [MainController numberOfSpacesRows]) {
					switchedSpace = [MainController switchToSpaceRow:row + 1 column:col];
					
					warpLocation.x = mouseLocation.x;
					warpLocation.y = _totalScreenRect.origin.y + 20;
					mouseLocation.y -= 3;
				}
				break;
			case UpDirection:
				if (_wraparound && row == 1) {
					//Wrap to the lowest space
					row = [MainController numberOfSpacesRows] + 1;
				}
				
				if ((edge = edgeForValueInRange(_vEdges, mouseLocation.y, mouseLocation.x)) && edge->isLeftOrTop && row > 1) {
					switchedSpace = [MainController switchToSpaceRow:row - 1 column:col];
					
					warpLocation.x = mouseLocation.x;
					warpLocation.y = _totalScreenRect.origin.y + _totalScreenRect.size.height - 20;
					mouseLocation.y += 3;
				}
				break;
		}
		
		if (switchedSpace) {
			CGWarpMouseCursorPosition(_warpMouse ? warpLocation : mouseLocation);
		}
	}
}

+ (BOOL)switchToSpaceRow:(NSInteger)row column:(NSInteger)column
{
	NSInteger rows = [self numberOfSpacesRows];
	NSInteger cols = [self numberOfSpacesColumns];
	NSInteger targetSpace = ((row - 1) * cols) + column - 1;
	
	//Check to make sure the given row and column is valid
	//Do nothing if it isn't
	if (targetSpace >= 0 && targetSpace < rows * cols) {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:SwitchSpacesNotification object:[NSString stringWithFormat:@"%d", targetSpace]];
		return YES;
	}
	
	return NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
	EventTypeSpec eventType[2];
	eventType[0].eventClass = kEventClassMouse;
	eventType[0].eventKind = kEventMouseMoved;
	eventType[1].eventClass = kEventClassMouse;
	eventType[1].eventKind = kEventMouseDragged;

	EventHandlerUPP handlerFunction = NewEventHandlerUPP(mouseMovedHandler);
	InstallEventHandler(GetEventMonitorTarget(), handlerFunction, 2, eventType, nil, &mouseHandler);
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:NSApp selector:@selector(terminate:) name:@"TerminateWarpNotification" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:@"WarpDefaultsChanged" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenParametersChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
	
	[self performSelector:@selector(defaultsChanged:)];
	[self performSelector:@selector(screenParametersChanged:)];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(timeMachineNotification:) name:@"com.apple.backup.BackupTargetActivatedNotification" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(timeMachineNotification:) name:@"com.apple.backup.BackupDismissedNotification" object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)note
{
	RemoveEventHandler(mouseHandler);
	
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:NSApp name:@"TerminateWarpNotification" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WarpDefaultsChanged" object:nil];
}

- (void)timeMachineNotification:(NSNotification *)note
{
	_timeMachineActive = [[note name] isEqualToString:@"com.apple.backup.BackupTargetActivatedNotification"];
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
}

- (void)screenParametersChanged:(NSNotification *)note
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
		
		#ifdef TEST_BOUNDS
			CGRect testDisplays[2];
			testDisplays[0] = CGRectMake(0, 0, 1600, 1200);
			testDisplays[1] = CGRectMake(1200, -768, 1024, 768);
			count = 2;
		#endif
		
		for (NSUInteger i = 0; i < count; i++) {
			#ifdef TEST_BOUNDS
				bounds = testDisplays[i];
				NSLog(@"bounds: %@", NSStringFromRect(*(NSRect *)&bounds));
			#else
				bounds = CGDisplayBounds(displays[i]);
			#endif
			
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
						_hEdges = addEdgeWithoutOverlap(_hEdges, bounds.origin.x, YES, WarpMakeRange(bounds.origin.y, bounds.size.height), edge);
					}
				}
			} else {
				_hEdges = addEdge(_hEdges, bounds.origin.x, YES, WarpMakeRange(bounds.origin.y, bounds.size.height));
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
						_hEdges = addEdgeWithoutOverlap(_hEdges, point, NO, WarpMakeRange(bounds.origin.y, bounds.size.height), edge);
					}
				}
			} else {
				_hEdges = addEdge(_hEdges, point, NO, WarpMakeRange(bounds.origin.y, bounds.size.height));
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
						_vEdges = addEdgeWithoutOverlap(_vEdges, bounds.origin.y, YES, WarpMakeRange(bounds.origin.x, bounds.size.width), edge);
					}
				}
			} else {
				_vEdges = addEdge(_vEdges, bounds.origin.y, YES, WarpMakeRange(bounds.origin.x, bounds.size.width));
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
						_vEdges = addEdgeWithoutOverlap(_vEdges, point, NO, WarpMakeRange(bounds.origin.x, bounds.size.width), edge);
					}
				}
			} else {
				_vEdges = addEdge(_vEdges, point, NO, WarpMakeRange(bounds.origin.x, bounds.size.width));
			}
			
			_totalScreenRect = CGRectUnion(_totalScreenRect, bounds);
		}
	}
	
	//Log found edges
	//#ifdef TEST_BOUNDS
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
	//#endif
	
	free(displays);
}

@end
