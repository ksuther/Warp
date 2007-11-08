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
#import <SystemConfiguration/SystemConfiguration.h>

#define SENDER_STATE ([sender state] == NSOnState)

#define WARP_ENABLED_TAG 1
#define ACTIVATION_DELAY_TAG 2
#define MODIFIER_COMMAND_TAG 3
#define MODIFIER_OPTION_TAG 4
#define MODIFIER_CONTROL_TAG 5
#define MODIFIER_SHIFT_TAG 6
#define LAUNCH_AT_LOGIN_TAG 7

#define UPDATE_INTERVAL 864000
#define UPDATE_SITE [NSURL URLWithString:@"http://www.ksuther.com/warp/update.php"]
#define UPDATE_URL_STRING @"http://www.ksuther.com/warp/checkversion.php?v=%@"

NSString *WarpDaemonName = @"WarpDaemon";
NSString *WarpBundleIdentifier = @"com.ksuther.warp";

@implementation WarpPreferences

@synthesize warpEnabled, launchAtLogin;

- (id)initWithBundle:(NSBundle *)bundle
{
	if ([super initWithBundle:bundle]) {
		defaults = [[WarpDefaults alloc] init];
		_updateResponseData = [[NSMutableData alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[defaults release];
	[_updateResponseData release];
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
	
	[self willChangeValueForKey:@"launchAtLogin"];
	launchAtLogin = NO;
	
	for (id nextItem in [app loginItems]) {
		if ([[nextItem name] isEqualToString:WarpDaemonName]) {
			launchAtLogin = YES;
			break;
		}
	}
	[self didChangeValueForKey:@"launchAtLogin"];
	
	[super willSelect];
}

- (void)didSelect
{
	[self checkForUpdates:NO];
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

- (IBAction)checkForUpdatesNow:(id)sender
{
	[self checkForUpdates:YES];
}

- (void)checkForUpdates:(BOOL)notify
{
	NSTimeInterval timeSinceLastUpdate = [[defaults valueForKey:@"LastUpdate"] doubleValue];
	
	if (notify || timeSinceLastUpdate == 0 || [[NSDate dateWithTimeIntervalSinceReferenceDate:timeSinceLastUpdate] timeIntervalSinceNow] < -UPDATE_INTERVAL + 3600) {
		//Check for network reachability
		const char *host = "ksuther.com";
		BOOL reachable;
		SCNetworkConnectionFlags flags = 0;
		
		reachable = SCNetworkCheckReachabilityByName(host, &flags);
		
		_notifyForUpdates = notify;
		
		if (reachable && ((flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired))) {
			NSURL *updateURL = [NSURL URLWithString:[NSString stringWithFormat:UPDATE_URL_STRING, [[[self bundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];
			[_updateResponseData setData:[NSData data]];
			[[NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:updateURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15] delegate:self] retain];
		} else if (_notifyForUpdates) {
			NSBundle *bundle = [self bundle];
			NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"Error checking for updates", nil, bundle, nil);
			NSString *errorMsg = NSLocalizedStringFromTableInBundle(@"Warp was unable to check for updates.\n\n%@", nil, bundle, nil);
			NSString *errorReason = NSLocalizedStringFromTableInBundle(@"Unable to contact remote host.", nil, bundle, nil);
			
			NSBeginAlertSheet(errorTitle, nil, nil, nil,  [[self mainView] window], nil, nil, nil, nil, errorMsg, errorReason);
		}
	}
}

- (void)updateSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[[NSWorkspace sharedWorkspace] openURL:UPDATE_SITE];
	}
}

#pragma mark -
#pragma mark NSURLConnection handler methods
#pragma mark -

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSBundle *bundle = [self bundle];
	NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"Error checking for updates", nil, bundle, nil);
	NSString *errorMsg = NSLocalizedStringFromTableInBundle(@"Warp was unable to check for updates.\n\n%@", nil, bundle, nil);
	
	if (_notifyForUpdates) {
		NSBeginInformationalAlertSheet(errorTitle, nil, nil, nil,  [[self mainView] window], nil, nil, nil, nil, errorMsg, [error localizedDescription]);
	}
	
	[_updateResponseData setData:[NSData data]];
	[connection release];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[_updateResponseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSString *string = [[NSString alloc] initWithData:_updateResponseData encoding:NSASCIIStringEncoding];
	NSArray *lines = [string componentsSeparatedByString:@"\n"];
	NSDictionary *infoDictionary = [[self bundle] infoDictionary];
	NSString *currentVersionString = [infoDictionary objectForKey:@"CFBundleVersion"];
	
	[_updateResponseData setData:[NSData data]];
	
	if ([[lines objectAtIndex:0] intValue] > [[infoDictionary objectForKey:@"VersionNumber"] intValue]) {
		NSBundle *bundle = [self bundle];
		NSString *updateTitle = NSLocalizedStringFromTableInBundle(@"Update available", nil, bundle, nil);
		NSString *updateMessage = NSLocalizedStringFromTableInBundle(@"Warp %@ is available. Would you like to download the latest version? Version %@ is currently installed.", nil, bundle, nil);
		NSString *moreInfo = NSLocalizedStringFromTableInBundle(@"Download", nil, bundle, nil);
		NSString *ignore = NSLocalizedStringFromTableInBundle(@"Ignore", nil, bundle, nil);
		
		NSBeginInformationalAlertSheet(updateTitle, moreInfo, ignore, nil,  [[self mainView] window], self, @selector(updateSheetDidEnd:returnCode:contextInfo:), nil, nil, updateMessage, [lines objectAtIndex:1], currentVersionString);
	} else if (_notifyForUpdates) {
		NSBundle *bundle = [self bundle];
		NSString *noupdateTitle = NSLocalizedStringFromTableInBundle(@"No updates found", nil, bundle, nil);
		NSString *noupdateMessage = NSLocalizedStringFromTableInBundle(@"Warp %@ is the newest version available.", nil, bundle, nil);
		
		NSBeginInformationalAlertSheet(noupdateTitle, nil, nil, nil,  [[self mainView] window], nil, nil, nil, nil, noupdateMessage, currentVersionString);
	}
	
	[connection release];
	
	[defaults setValue:[NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]] forKey:@"LastUpdate"];
}

@end
