//
//  WarpPreferences.m
//  Warp
//
//  Created by Kent Sutherland on 11/2/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import "WarpPreferences.h"

#define SENDER_STATE ([sender state] == NSOnState)

#define WARP_ENABLED_TAG 1
#define ACTIVATION_DELAY_TAG 2
#define MODIFIER_COMMAND_TAG 3
#define MODIFIER_OPTION_TAG 4
#define MODIFIER_CONTROL_TAG 5
#define MODIFIER_SHIFT_TAG 6

NSString *WarpBundleIdentifier = @"com.ksuther.warp";

@implementation WarpPreferences

+ (BOOL)isWarpDaemonRunning
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

+ (void)setObject:(id)object forKey:(NSString *)key
{
	NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *dictionary = [[[df persistentDomainForName:WarpBundleIdentifier] mutableCopy] autorelease];
	
	if (!dictionary) {
		dictionary = [NSMutableDictionary dictionary];
	}
	
	[dictionary setObject:object forKey:key];
	[df setPersistentDomain:dictionary forName:WarpBundleIdentifier];
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"WarpDefaultsChanged" object:nil];
}

+ (id)objectForKey:(NSString *)key
{
	return [(id)CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)WarpBundleIdentifier) autorelease];
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
	
	//Restore preferences
	[_warpEnabledCheckbox setState:[WarpPreferences isWarpDaemonRunning] ? NSOnState : NSOffState];
	
	float delay = [[WarpPreferences objectForKey:@"Delay"] floatValue];
	[_activationDelaySlider setFloatValue:delay];
	[_activationDelayTextField setFloatValue:delay];
	
	id modifiers = [WarpPreferences objectForKey:@"Modifiers"];
	
	if (modifiers) {
		[_commandKeyCheckbox setState:[[modifiers objectForKey:@"Command"] boolValue] ? NSOnState : NSOffState];
		[_optionKeyCheckbox setState:[[modifiers objectForKey:@"Option"] boolValue] ? NSOnState : NSOffState];
		[_controlKeyCheckbox setState:[[modifiers objectForKey:@"Control"] boolValue] ? NSOnState : NSOffState];
		[_shiftKeyCheckbox setState:[[modifiers objectForKey:@"Shift"] boolValue] ? NSOnState : NSOffState];
	} else {
		[_commandKeyCheckbox setState:NSOnState];
	}
	
	[super willSelect];
}

- (void)willUnselect
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:nil object:nil];
}

- (void)workspaceNotificationReceived:(NSNotification *)note
{
	if ([[[note userInfo] objectForKey:@"NSApplicationBundleIdentifier"] isEqualToString:WarpBundleIdentifier]) {
		if ([[note name] isEqualToString:NSWorkspaceDidLaunchApplicationNotification]) {
			//Warp daemon launched
			[_warpEnabledCheckbox setState:NSOnState];
		} else {
			//Warp daemon quit
			[_warpEnabledCheckbox setState:NSOffState];
		}
	}
}

#pragma mark -
#pragma mark IBActions
#pragma mark -

- (IBAction)changeWarpSetting:(id)sender
{
	switch ([sender tag]) {
		case WARP_ENABLED_TAG:
			if ([sender state] == NSOffState) {
				//Tell Warp to quit
				[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"TerminateWarpNotification" object:nil];
			} else {
				//Launch Warp
				NSString *daemonPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"WarpDaemon" ofType:@"app"];
				
				if (daemonPath) {
					[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:[NSURL fileURLWithPath:daemonPath]]
									withAppBundleIdentifier:nil
													options:NSWorkspaceLaunchWithoutAddingToRecents | NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchAsync
							additionalEventParamDescriptor:nil
										launchIdentifiers:nil];
				} else {
					#warning WARN - DAEMON NOT FOUND
				}
			}
			break;
		case ACTIVATION_DELAY_TAG:
			[WarpPreferences setObject:[NSNumber numberWithFloat:[sender floatValue]] forKey:@"Delay"];
			[_activationDelayTextField setFloatValue:[sender floatValue]];
			break;
	}
}

- (IBAction)changeModifierSetting:(id)sender
{
	NSMutableDictionary *modifiers = [[[WarpPreferences objectForKey:@"Modifiers"] mutableCopy] autorelease];
	
	if (!modifiers) {
		modifiers = [NSMutableDictionary dictionary];
	}
	
	switch ([sender tag]) {
		case MODIFIER_COMMAND_TAG:
			[modifiers setObject:[NSNumber numberWithBool:SENDER_STATE] forKey:@"Command"];
			break;
		case MODIFIER_OPTION_TAG:
			[modifiers setObject:[NSNumber numberWithBool:SENDER_STATE] forKey:@"Option"];
			break;
		case MODIFIER_CONTROL_TAG:
			[modifiers setObject:[NSNumber numberWithBool:SENDER_STATE] forKey:@"Control"];
			break;
		case MODIFIER_SHIFT_TAG:
			[modifiers setObject:[NSNumber numberWithBool:SENDER_STATE] forKey:@"Shift"];
			break;
	}
	
	[WarpPreferences setObject:modifiers forKey:@"Modifiers"];
}

@end
