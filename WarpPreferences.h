//
//  WarpPreferences.h
//  Warp
//
//  Created by Kent Sutherland on 11/2/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/PreferencePanes.h>

extern NSString *WarpBundleIdentifier;

@class WarpDefaults;

@interface WarpPreferences : NSPreferencePane {
	IBOutlet NSTextView *_aboutTextView;
	
	BOOL warpEnabled, launchAtLogin;
	WarpDefaults *defaults;
	
	NSMutableData *_updateResponseData;
	BOOL _notifyForUpdates;
}

@property BOOL warpEnabled;
@property BOOL launchAtLogin;

- (BOOL)isWarpDaemonRunning;

- (IBAction)checkForUpdatesNow:(id)sender;
- (void)checkForUpdates:(BOOL)notify;

@end
