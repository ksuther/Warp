//
//  WarpPreferences.h
//  Warp
//
//  Created by Kent Sutherland on 11/2/07.
//  Copyright 2007-2009 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/PreferencePanes.h>

extern NSString *WarpBundleIdentifier;

@class WarpDefaults, SRRecorderControl;

@interface WarpPreferences : NSPreferencePane {
	IBOutlet NSTextView *_aboutTextView;
	IBOutlet SRRecorderControl *_recorderControl;
	
	BOOL warpEnabled, launchAtLogin;
	WarpDefaults *defaults;
	
	NSMutableData *_updateResponseData;
	BOOL _notifyForUpdates;
	BOOL _receivedDaemonVersion;
}

@property BOOL warpEnabled;
@property BOOL launchAtLogin;

- (NSString *)CFBundleVersion;
- (BOOL)isWarpDaemonRunning;

- (IBAction)checkForUpdatesNow:(id)sender;
- (void)checkForUpdates:(BOOL)notify;

@end
