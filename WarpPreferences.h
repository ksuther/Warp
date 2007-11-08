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
}

@property BOOL warpEnabled;
@property BOOL launchAtLogin;

- (BOOL)isWarpDaemonRunning;

@end
