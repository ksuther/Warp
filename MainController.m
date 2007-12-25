//
//  MainController.m
//  Edger
//
//  Created by Kent Sutherland on 11/1/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import "MainController.h"
#import "CoreGraphicsPrivate.h"

NSString *SwitchSpacesNotification = @"com.apple.switchSpaces";

Edge * edgeForValue(Edge *edge, float value) {
	while (edge) {
		if (edge->point == value) {
			return edge;
		}
		edge = edge->next;
	}
	
	return nil;
}

float _activationDelay;
NSUInteger _activationModifiers;
BOOL _warpMouse, _wraparound;
Edge *_hEdges = nil, *_vEdges = nil;
CGRect _totalScreenRect;

OSStatus mouseMovedHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
	HIPoint mouseLocation;
	NSInteger direction = -1;
	
	HIGetMousePosition(kHICoordSpaceScreenPixel, NULL, &mouseLocation);
	
	Edge *edge;
	
	if ( (edge = edgeForValue(_hEdges, mouseLocation.x)) ) {
		direction = edge->isLeftOrTop ? LeftDirection : RightDirection;
	} else if ( (edge = edgeForValue(_vEdges, mouseLocation.y)) ) {
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
	if (_activationModifiers == 0 || (GetCurrentKeyModifiers() & _activationModifiers) == _activationModifiers) {
		NSDictionary *info = [timer userInfo];
		HIPoint mouseLocation;
		CGPoint warpLocation;
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
				
				if ((edge = edgeForValue(_hEdges, mouseLocation.x)) && edge->isLeftOrTop && col > 1) {
					switchedSpace = [MainController switchToSpaceRow:row column:col - 1];
					
					warpLocation.x = _totalScreenRect.origin.x + _totalScreenRect.size.width - 20;
					warpLocation.y = mouseLocation.y;
				}
				break;
			case RightDirection:
				if (_wraparound && col == [MainController numberOfSpacesColumns]) {
					//Wrap to the leftmost space
					col = 0;
				}
				
				if ((edge = edgeForValue(_hEdges, mouseLocation.x)) && !edge->isLeftOrTop && col < [MainController numberOfSpacesColumns]) {
					switchedSpace = [MainController switchToSpaceRow:row column:col + 1];
					
					warpLocation.x = _totalScreenRect.origin.x + 20;
					warpLocation.y = mouseLocation.y;
				}
				break;
			case DownDirection:
				if (_wraparound && row == [MainController numberOfSpacesRows]) {
					//Wrap to the top space
					row = 0;
				}
				
				if ((edge = edgeForValue(_vEdges, mouseLocation.y)) && !edge->isLeftOrTop && row < [MainController numberOfSpacesRows]) {
					switchedSpace = [MainController switchToSpaceRow:row + 1 column:col];
					
					warpLocation.x = mouseLocation.x;
					warpLocation.y = _totalScreenRect.origin.y + 20;
				}
				break;
			case UpDirection:
				if (_wraparound && row == 1) {
					//Wrap to the lowest space
					row = [MainController numberOfSpacesRows] + 1;
				}
				
				if ((edge = edgeForValue(_vEdges, mouseLocation.y)) && edge->isLeftOrTop && row > 1) {
					switchedSpace = [MainController switchToSpaceRow:row - 1 column:col];
					
					warpLocation.x = mouseLocation.x;
					warpLocation.y = _totalScreenRect.origin.y + _totalScreenRect.size.height - 20;
				}
				break;
		}
		
		if (switchedSpace && _warpMouse) {
			NSLog(@"warp to: %@", NSStringFromPoint(*(NSPoint *)&warpLocation));
			CGWarpMouseCursorPosition(warpLocation);
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
}

- (void)applicationWillTerminate:(NSNotification *)note
{
	RemoveEventHandler(mouseHandler);
	
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:NSApp name:@"TerminateWarpNotification" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WarpDefaultsChanged" object:nil];
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
	displays = calloc(1, count * sizeof(displays[0]));
	
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
		
		for (NSUInteger i = 0; i < count; i++) {
			bounds = CGDisplayBounds(displays[i]);
			
			if ( (edge = edgeForValue(_hEdges, bounds.origin.x - 1)) || (edge = edgeForValue(_hEdges, bounds.origin.x + 1)) ) {
				if (edge->prev) {
					edge->prev = edge->next;
				} else {
					_hEdges = edge->next;
				}
				
				free(edge);
			} else {
				edge = malloc(sizeof(Edge));
				edge->point = bounds.origin.x;
				edge->isLeftOrTop = YES;
				edge->next = _hEdges;
				edge->prev = nil;
				
				if (_hEdges) {
					_hEdges->prev = edge;
				}
				
				_hEdges = edge;
			}
			
			if ( (edge = edgeForValue(_hEdges, bounds.origin.x + bounds.size.width - 1)) || (edge = edgeForValue(_hEdges, bounds.origin.x + bounds.size.width + 1)) ) {
				if (edge->prev) {
					edge->prev = edge->next;
				} else {
					_hEdges = edge->next;
				}
				
				free(edge);
			} else {
				edge = malloc(sizeof(Edge));
				edge->point = bounds.origin.x + bounds.size.width - 1;
				
				if (edge->point < 0) {
					edge->point = 0;
				}
				
				edge->isLeftOrTop = NO;
				edge->next = _hEdges;
				edge->prev = nil;
				
				if (_hEdges) {
					_hEdges->prev = edge;
				}
				
				_hEdges = edge;
			}
			
			if ( (edge = edgeForValue(_vEdges, bounds.origin.y - 1)) || (edge = edgeForValue(_vEdges, bounds.origin.y + 1)) ) {
				if (edge->prev) {
					edge->prev = edge->next;
				} else {
					_vEdges = edge->next;
				}
				
				free(edge);
			} else {
				edge = malloc(sizeof(Edge));
				edge->point = bounds.origin.y;
				edge->isLeftOrTop = YES;
				edge->next = _vEdges;
				edge->prev = nil;
				
				if (_vEdges) {
					_vEdges->prev = edge;
				}
				
				_vEdges = edge;
			}
			
			if ( (edge = edgeForValue(_vEdges, bounds.origin.y + bounds.size.height - 1)) || (edge = edgeForValue(_vEdges, bounds.origin.y + bounds.size.height + 1)) ) {
				if (edge->prev) {
					edge->prev = edge->next;
				} else {
					_vEdges = edge->next;
				}
				
				free(edge);
			} else {
				edge = malloc(sizeof(Edge));
				edge->point = bounds.origin.y + bounds.size.height - 1;
				
				if (edge->point < 0) {
					edge->point = 0;
				}
				
				edge->isLeftOrTop = NO;
				edge->next = _vEdges;
				edge->prev = nil;
				
				if (_vEdges) {
					_vEdges->prev = edge;
				}
				
				_vEdges = edge;
			}
			
			_totalScreenRect = CGRectUnion(_totalScreenRect, bounds);
		}
	}
	
	//Log found edges
	edge = _hEdges;
	while (edge != nil) {
		NSLog(@"horizontal edge: %f isLeftOrTop: %d", edge->point, edge->isLeftOrTop);
		edge = edge->next;
	}
	edge = _vEdges;
	while (edge != nil) {
		NSLog(@"vertical edge: %f isLeftOrTop: %d", edge->point, edge->isLeftOrTop);
		edge = edge->next;
	}
	
	free(displays);
}

@end
