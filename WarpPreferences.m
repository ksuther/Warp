//
//  WarpPreferences.m
//  Warp
//
//  Created by Kent Sutherland on 11/2/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import "WarpPreferences.h"
#import "WarpDefaults.h"
#import "SystemEvents.h"

#define SENDER_STATE ([sender state] == NSOnState)

#define WARP_ENABLED_TAG 1
#define ACTIVATION_DELAY_TAG 2
#define MODIFIER_COMMAND_TAG 3
#define MODIFIER_OPTION_TAG 4
#define MODIFIER_CONTROL_TAG 5
#define MODIFIER_SHIFT_TAG 6
#define LAUNCH_AT_LOGIN_TAG 7

NSString *WarpDaemonName = @"WarpDaemon";
NSString *WarpBundleIdentifier = @"com.ksuther.warp";

@implementation WarpPreferences

@synthesize warpEnabled, launchAtLogin;

- (id)initWithBundle:(NSBundle *)bundle
{
	if ([super initWithBundle:bundle]) {
		defaults = [[WarpDefaults alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[defaults release];
	[super dealloc];
}

- (NSString *)mainNibName
{
	return @"WarpPreferences";
}

- (void)willSelect
{
	//Listen for application launch/quit notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceNotificationReceived:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceNotificationReceived:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
	
	//Set about string
	NSDictionary *linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSURL URLWithString:@"http://www.ksuther.com/warp/"], NSLinkAttributeName, [NSCursor pointingHandCursor], NSCursorAttributeName, nil];
	[[_aboutTextView textStorage] addAttributes:linkAttributes range:NSMakeRange(0, [[_aboutTextView textStorage] length])];
	
	//Restore preferences
	[self willChangeValueForKey:@"warpEnabled"];
	warpEnabled = [self isWarpDaemonRunning];
	[self didChangeValueForKey:@"warpEnabled"];
	
	//Check if WarpDaemon is in the login items
	SystemEventsApplication *app = [SBApplication applicationWithBundleIdentifier:@"com.apple.systemevents"];
	
	[self willChangeValueForKey:@"warpEnabled"];
	launchAtLogin = NO;
	for (id nextItem in [app loginItems]) {
		if ([[nextItem name] isEqualToString:WarpDaemonName]) {
			launchAtLogin = YES;
			break;
		}
	}
	[self didChangeValueForKey:@"warpEnabled"];
	
	[super willSelect];
}

- (void)willUnselect
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:nil object:nil];
}

- (void)workspaceNotificationReceived:(NSNotification *)note
{
	if ([[[note userInfo] objectForKey:@"NSApplicationBundleIdentifier"] isEqualToString:WarpBundleIdentifier]) {
		[self willChangeValueForKey:@"warpEnabled"];
		warpEnabled = [[note name] isEqualToString:NSWorkspaceDidLaunchApplicationNotification];
		[self didChangeValueForKey:@"warpEnabled"];
	}
}

- (BOOL)isWarpDaemonRunning
{
	ProcessSerialNumber number = {kNoProcess, kNoProcess};
	NSDictionary *processInfo;
	
	while (GetNextProcess(&number) == noErr)  {
		processInfo = (NSDictionary *)ProcessInformationCopyDictionary(&number, kProcessDictionaryIncludeAllInformationMask);
		
		if ([[processInfo objectForKey:(NSString *)kCFBundleIdentifierKey] isEqualToString:WarpBundleIdentifier]) {
			return YES;
		}
		
		[processInfo release];
	}
	
	return NO;
}

- (void)setWarpEnabled:(BOOL)enabled
{
	if (enabled) {
		//Launch Warp
		NSString *daemonPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"WarpDaemon" ofType:@"app"];
		
		if (daemonPath) {
			[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:[NSURL fileURLWithPath:daemonPath]]
							withAppBundleIdentifier:nil
											options:NSWorkspaceLaunchWithoutAddingToRecents | NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchAsync
					additionalEventParamDescriptor:nil
								launchIdentifiers:nil];
		} else {
			NSBundle *bundle = [self bundle];
			NSString *title = NSLocalizedStringFromTableInBundle(@"Resource missing", nil, bundle, nil);
			NSString *message = NSLocalizedStringFromTableInBundle(@"Warp is missing a resource required to function. Please reinstall Warp.", nil, bundle, nil);
			
			NSBeginAlertSheet(title, nil, nil, nil, [[self mainView] window], nil, nil, nil, nil, message);
		}
	} else {
		//Tell Warp to quit
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"TerminateWarpNotification" object:nil];
	}
	
	warpEnabled = enabled;
}

- (void)setLaunchAtLogin:(BOOL)enabled
{
	SystemEventsApplication *app = [SBApplication applicationWithBundleIdentifier:@"com.apple.systemevents"];
	
	if (enabled) {
		//Add to login items
		NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:[[NSBundle bundleForClass:[self class]] pathForResource:WarpDaemonName ofType:@"app"], @"path", [NSNumber numberWithBool:NO], @"hidden", nil];
		SBObject *object = [[[SBObject alloc] initWithElementCode:'logi' properties:properties data:nil] autorelease];
		
		[[app loginItems] addObject:object];
	} else {
		//Remove from login items
		for (id nextItem in [app loginItems]) {
			if ([[nextItem name] isEqualToString:WarpDaemonName]) {
				[[app loginItems] removeObject:nextItem];
				break;
			}
		}
	}
	
	launchAtLogin = enabled;
}

@end
