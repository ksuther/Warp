//
//  WarpPreferences.m
//  Warp
//
//  Created by Kent Sutherland on 11/2/07.
//  Copyright 2007-2009 Kent Sutherland. All rights reserved.
//

#import "WarpPreferences.h"
#import "WarpDefaults.h"
#import "SystemEvents.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "SRRecorderControl.h"

#define SENDER_STATE ([sender state] == NSOnState)

#define WARP_ENABLED_TAG 1
#define ACTIVATION_DELAY_TAG 2
#define MODIFIER_COMMAND_TAG 3
#define MODIFIER_OPTION_TAG 4
#define MODIFIER_CONTROL_TAG 5
#define MODIFIER_SHIFT_TAG 6
#define LAUNCH_AT_LOGIN_TAG 7

#define UPDATE_INTERVAL 864000
#define UPDATE_SITE [NSURL URLWithString:@"http://www.ksuther.com/warp/update"]
#define UPDATE_URL_STRING @"http://www.ksuther.com/warp/checkversion.php?v=%@"

#define DONATE_URL [NSURL URLWithString:@"http://www.ksuther.com/warp/donate"]

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
	
	//Ensure the running daemon matches the version of the prefpane
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(versionResponse:) name:@"WarpVersionResponse" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"WarpVersionRequest" object:nil];
	[self performSelector:@selector(versionRequestTimeout) withObject:nil afterDelay:2.0];
	
	//Set about string
	NSDictionary *linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSURL URLWithString:@"http://www.ksuther.com/warp/"], NSLinkAttributeName, [NSCursor pointingHandCursor], NSCursorAttributeName, nil];
	[[_aboutTextView textStorage] addAttributes:linkAttributes range:NSMakeRange(0, [[_aboutTextView textStorage] length])];
	
	//Restore preferences
	[self willChangeValueForKey:@"warpEnabled"];
	warpEnabled = [self isWarpDaemonRunning];
	[self didChangeValueForKey:@"warpEnabled"];
	
	short code = [[defaults valueForKey:@"PagerKeyCode"] shortValue];
	
	if (code != 0) {
		unsigned int flags = SRCarbonToCocoaFlags([[defaults valueForKey:@"PagerModifierFlags"] unsignedIntValue]);
		
		[_recorderControl setKeyCombo:SRMakeKeyCombo(code, flags)];
	}
	
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
	
	//Using Scripting Bridge to the get the Spaces enabled property from System Events doesn't seem to work
	CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
	if (!CFPreferencesGetAppBooleanValue(CFSTR("workspaces"), CFSTR("com.apple.dock"), nil)) {
		NSBundle *bundle = [self bundle];
		NSString *spacesDisabledTitle = NSLocalizedStringFromTableInBundle(@"Spaces is disabled", nil, bundle, nil);
		NSString *spacesDisabledMsg = NSLocalizedStringFromTableInBundle(@"Spaces must be enabled for Warp to function. Would you like to go to the Spaces preference pane?", nil, bundle, nil);
		
		//NSBeginInformationalAlertSheet(spacesDisabledTitle, @"Yes", @"No", nil,  [[self mainView] window], self, @selector(spacesDisabledSheetDidEnd:returnCode:contextInfo:), nil, nil, spacesDisabledMsg);
		NSAlert *alert = [NSAlert alertWithMessageText:spacesDisabledTitle defaultButton:NSLocalizedStringFromTableInBundle(@"Yes", nil, bundle, nil) alternateButton:NSLocalizedStringFromTableInBundle(@"No", nil, bundle, nil) otherButton:nil informativeTextWithFormat:spacesDisabledMsg];
		[alert setIcon:[[[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForImageResource:@"Warp"]] autorelease]];
		[alert beginSheetModalForWindow:[[self mainView] window] modalDelegate:self didEndSelector:@selector(spacesDisabledSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	
	//Update the launch count if less than 3
	NSNumber *count = [defaults valueForKey:@"PrefPaneUseCount"];
	
	if (!count || ![count isKindOfClass:[NSNumber class]]) {
		count = [NSNumber numberWithInt:1];
	} else {
		count = [NSNumber numberWithInt:[count intValue] + 1];
	}
	
	if ([count intValue] <= 5) {
		[defaults setValue:count forKey:@"PrefPaneUseCount"];
	}
	
	if ([count intValue] == 1 || [count intValue] == 4) {
		//Run the donate request sheet
		NSBundle *bundle = [self bundle];
		NSString *donateRequestTitle = NSLocalizedStringFromTableInBundle(@"Please consider donating", nil, bundle, nil);
		NSString *donateRequestMsg = NSLocalizedStringFromTableInBundle(@"Warp is free to use, but donations help to support the future development of Warp. Please consider donating if you find Warp to be a useful addition to your system.", nil, bundle, nil);
		NSAlert *alert = [NSAlert alertWithMessageText:donateRequestTitle defaultButton:NSLocalizedStringFromTableInBundle(@"Donate", nil, bundle, nil) alternateButton:NSLocalizedStringFromTableInBundle(@"Close", nil, bundle, nil) otherButton:nil informativeTextWithFormat:donateRequestMsg];
		[alert setIcon:[[[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForImageResource:@"Warp"]] autorelease]];
		[alert beginSheetModalForWindow:[[self mainView] window] modalDelegate:self didEndSelector:@selector(donateSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

- (void)willUnselect
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:nil object:nil];
}

- (NSString *)CFBundleVersion
{
	NSString *plistPath = [[[self bundle] bundlePath] stringByAppendingPathComponent:@"Contents/Info.plist"];
	
	return [[NSDictionary dictionaryWithContentsOfFile:plistPath] objectForKey:@"CFBundleVersion"];
}

- (NSString *)versionString
{
	return [NSString stringWithFormat:@"%@ -", [self CFBundleVersion]];
}

- (void)launchDaemon
{
	[self setWarpEnabled:YES];
}

- (void)versionRequestTimeout
{
	if (!_receivedDaemonVersion && [self isWarpDaemonRunning]) {
		[self setWarpEnabled:NO];
		[self performSelector:@selector(launchDaemon) withObject:nil afterDelay:1.0];
	}
}

- (void)versionResponse:(NSNotification *)note
{
	_receivedDaemonVersion = YES;
	
	if (![[self CFBundleVersion] isEqualToString:[note object]]) {
		[self setWarpEnabled:NO];
		[self performSelector:@selector(launchDaemon) withObject:nil afterDelay:1.0];
	}
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
    if (enabled) {
		//Add to login items
        NSString *daemonPath = [[NSBundle bundleForClass:[self class]] pathForResource:WarpDaemonName ofType:@"app"];
        NSString *source = [NSString stringWithFormat:@"tell application \"System Events\" to make new login item with properties {path:\"%@\", hidden:false} at end", daemonPath];
        NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:source] autorelease];
        
		[script executeAndReturnError:nil];
	} else {
        //Remove from login items
        SystemEventsApplication *app = [SBApplication applicationWithBundleIdentifier:@"com.apple.systemevents"];
        
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
	
	if (notify || ([[defaults valueForKey:@"CheckForUpdates"] boolValue] && (timeSinceLastUpdate == 0 || [[NSDate dateWithTimeIntervalSinceReferenceDate:timeSinceLastUpdate] timeIntervalSinceNow] < -UPDATE_INTERVAL + 3600))) {
		//Check for network reachability
		const char *host = "ksuther.com";
		BOOL reachable;
		SCNetworkConnectionFlags flags = 0;
		
		reachable = SCNetworkCheckReachabilityByName(host, &flags);
		
		_notifyForUpdates = notify;
		
		if (reachable && ((flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired))) {
			NSURL *updateURL = [NSURL URLWithString:[NSString stringWithFormat:UPDATE_URL_STRING, [[[self bundle] infoDictionary] objectForKey:@"VersionNumber"]]];
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

#pragma mark -
#pragma mark ShortcutRecorder Delegate

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo
{
	[defaults setValue:[NSNumber numberWithShort:newKeyCombo.code] forKey:@"PagerKeyCode"];
	[defaults setValue:[NSNumber numberWithUnsignedInt:SRCocoaToCarbonFlags(newKeyCombo.flags)] forKey:@"PagerModifierFlags"];
}

- (BOOL)shortcutRecorder:(SRRecorderControl *)aRecorder isKeyCode:(NSInteger)keyCode andFlagsTaken:(NSUInteger)flags reason:(NSString **)aReason
{
	return NO;
}

#pragma mark -
#pragma mark Sheet Callbacks
#pragma mark -

- (void)updateSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[[NSWorkspace sharedWorkspace] openURL:UPDATE_SITE];
	}
}

- (void)spacesDisabledSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		//Too bad I can't use Scripting Bridge doesn't like being called from within the same application
		NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:@"tell application \"System Preferences\"\nreveal anchor \"Spaces\" of pane id \"com.apple.preference.expose\"\nend tell"] autorelease];
		[script performSelector:@selector(executeAndReturnError:) withObject:nil afterDelay:0.0];
	}
}

- (void)donateSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[[NSWorkspace sharedWorkspace] openURL:DONATE_URL];
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
		//NSBeginInformationalAlertSheet(errorTitle, nil, nil, nil,  [[self mainView] window], nil, nil, nil, nil, errorMsg, [error localizedDescription]);
		NSAlert *alert = [NSAlert alertWithMessageText:errorTitle defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:errorMsg, [error localizedDescription]];
		[alert setIcon:[[[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForImageResource:@"Warp"]] autorelease]];
		[alert beginSheetModalForWindow:[[self mainView] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
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
		
		//NSBeginInformationalAlertSheet(updateTitle, moreInfo, ignore, nil,  [[self mainView] window], self, @selector(updateSheetDidEnd:returnCode:contextInfo:), nil, nil, updateMessage, [lines objectAtIndex:1], currentVersionString);
		NSAlert *alert = [NSAlert alertWithMessageText:updateTitle defaultButton:moreInfo alternateButton:ignore otherButton:nil informativeTextWithFormat:updateMessage, [lines objectAtIndex:1], currentVersionString];
		[alert setIcon:[[[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForImageResource:@"Warp"]] autorelease]];
		[alert beginSheetModalForWindow:[[self mainView] window] modalDelegate:self didEndSelector:@selector(updateSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
	} else if (_notifyForUpdates) {
		NSBundle *bundle = [self bundle];
		NSString *noupdateTitle = NSLocalizedStringFromTableInBundle(@"No updates found", nil, bundle, nil);
		NSString *noupdateMessage = NSLocalizedStringFromTableInBundle(@"Warp %@ is the newest version available.", nil, bundle, nil);
		
		//NSBeginInformationalAlertSheet(noupdateTitle, nil, nil, nil,  [[self mainView] window], nil, nil, nil, nil, noupdateMessage, currentVersionString);
		NSAlert *alert = [NSAlert alertWithMessageText:noupdateTitle defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:noupdateMessage, currentVersionString];
		[alert setIcon:[[[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForImageResource:@"Warp"]] autorelease]];
		[alert beginSheetModalForWindow:[[self mainView] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
	
	[connection release];
	
	[defaults setValue:[NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]] forKey:@"LastUpdate"];
}

@end
