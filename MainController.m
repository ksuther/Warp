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

float _activationDelay = 0.5;
NSUInteger _activationModifiers = cmdKey;
BOOL _warpMouse = NO;
NSRect _totalScreenRect;

enum {
	LeftDirection = 0,
	RightDirection,
	UpDirection,
	DownDirection
};

OSStatus mouseMovedHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
	NSPoint mouseLocation = [NSEvent mouseLocation];
	NSInteger direction = -1;
	
	if (mouseLocation.x == _totalScreenRect.origin.x) {
		direction = LeftDirection;
	} else if (mouseLocation.x == _totalScreenRect.size.width - 1) {
		direction = RightDirection;
	} else if (mouseLocation.y == _totalScreenRect.origin.y + 1) {
		direction = DownDirection;
	} else if (mouseLocation.y == _totalScreenRect.size.height) {
		direction = UpDirection;
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
	return CFPreferencesGetAppIntegerValue(CFSTR("workspaces-rows"), CFSTR("com.apple.dock"), nil);
}

+ (NSInteger)numberOfSpacesColumns
{
	CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
	return CFPreferencesGetAppIntegerValue(CFSTR("workspaces-cols"), CFSTR("com.apple.dock"), nil);
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
		NSPoint mouseLocation = [NSEvent mouseLocation];
		CGPoint warpLocation;
		int row, col;
		BOOL switchedSpace = NO;
		
		[MainController getCurrentSpaceRow:&row column:&col];
		
		switch ([[info objectForKey:@"Direction"] intValue]) {
			case LeftDirection:
				if (mouseLocation.x == _totalScreenRect.origin.x && col > 1) {
					switchedSpace = [MainController switchToSpaceRow:row column:col - 1];
					
					warpLocation.x = _totalScreenRect.size.width - 20;
					warpLocation.y = _totalScreenRect.size.height - mouseLocation.y;
				}
				break;
			case RightDirection:
				if (mouseLocation.x == _totalScreenRect.size.width - 1 && col < [MainController numberOfSpacesColumns]) {
					switchedSpace = [MainController switchToSpaceRow:row column:col + 1];
					
					warpLocation.x = _totalScreenRect.origin.x + 20;
					warpLocation.y = _totalScreenRect.size.height - mouseLocation.y;
				}
				break;
			case DownDirection:
				if (mouseLocation.y == _totalScreenRect.origin.y + 1 && row < [MainController numberOfSpacesRows]) {
					switchedSpace = [MainController switchToSpaceRow:row + 1 column:col];
					
					warpLocation.x = mouseLocation.x;
					warpLocation.y = _totalScreenRect.origin.y + 20;
				}
				break;
			case UpDirection:
				if (mouseLocation.y == _totalScreenRect.size.height && row > 1) {
					switchedSpace = [MainController switchToSpaceRow:row - 1 column:col];
					
					warpLocation.x = mouseLocation.x;
					warpLocation.y = _totalScreenRect.size.height - 20;
				}
				break;
		}
		
		if (switchedSpace && _warpMouse) {
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
	EventTypeSpec eventType;
	eventType.eventClass = kEventClassMouse;
	eventType.eventKind = kEventMouseMoved;

	EventHandlerUPP handlerFunction = NewEventHandlerUPP(mouseMovedHandler);
	InstallEventHandler(GetEventMonitorTarget(), handlerFunction, 1, &eventType, nil, &mouseHandler);
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:NSApp selector:@selector(terminate:) name:@"TerminateWarpNotification" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:@"WarpDefaultsChanged" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(screenParametersChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
	
	[self performSelector:@selector(defaultsChanged:)];
	[self performSelector:@selector(screenParametersChanged:)];
}

- (void)applicationWillTerminate:(NSNotification *)note
{
	RemoveEventHandler(mouseHandler);
	
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:NSApp name:@"TerminateWarpNotification" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:@"WarpDefaultsChanged" object:nil];
}

- (void)defaultsChanged:(NSNotification *)note
{
	NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
	
	[df synchronize];
	
	id object = [df objectForKey:@"Delay"];
	_activationDelay = (object) ? [object floatValue] : 0.5f;
	
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
}

- (void)screenParametersChanged:(NSNotification *)note
{
	NSArray *screens = [NSScreen screens];
	
	_totalScreenRect = NSZeroRect;
	
	for (NSScreen *screen in screens) {
		_totalScreenRect = NSUnionRect(_totalScreenRect, [screen frame]);
	}
}

@end
