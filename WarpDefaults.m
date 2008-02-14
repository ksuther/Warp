//
//  WarpDefaults.m
//  Warp
//
//  Created by Kent Sutherland on 11/8/07.
//  Copyright 2007-2008 Kent Sutherland. All rights reserved.
//

#import "WarpDefaults.h"
#import "WarpPreferences.h"

@implementation WarpDefaults

- (id)init
{
	if ([super init]) {
		if ([[NSUserDefaults standardUserDefaults] persistentDomainForName:WarpBundleIdentifier] == nil) {
			NSDictionary *defaultSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:0.75], @"Delay",
																					[NSNumber numberWithBool:NO], @"WarpMouse",
																					[NSNumber numberWithBool:YES], @"CheckForUpdates", nil];
			
			[[NSUserDefaults standardUserDefaults] setPersistentDomain:defaultSettings forName:WarpBundleIdentifier];
		}
	}
	return self;
}

- (void)setValue:(id)value forKey:(NSString *)key
{
	[self willChangeValueForKey:key];
	
	NSMutableDictionary *dictionary = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:WarpBundleIdentifier] mutableCopy];
	[dictionary setValue:value forKey:key];
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:dictionary forName:WarpBundleIdentifier];
	[dictionary release];
	
	[self didChangeValueForKey:key];
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"WarpDefaultsChanged" object:nil];
}

- (id)valueForKey:(NSString *)key
{
	return [[[NSUserDefaults standardUserDefaults] persistentDomainForName:WarpBundleIdentifier] valueForKey:key];
}

@end
