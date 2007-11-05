//
//  WarpPreferences.h
//  Warp
//
//  Created by Kent Sutherland on 11/2/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/PreferencePanes.h>

@interface WarpPreferences : NSPreferencePane {
	IBOutlet NSButton *_warpEnabledCheckbox;
	IBOutlet NSSlider *_activationDelaySlider;
	IBOutlet NSTextField *_activationDelayTextField;
	
	IBOutlet NSButton *_commandKeyCheckbox;
	IBOutlet NSButton *_optionKeyCheckbox;
	IBOutlet NSButton *_controlKeyCheckbox;
	IBOutlet NSButton *_shiftKeyCheckbox;
}

+ (BOOL)isWarpDaemonRunning;
+ (void)setObject:(id)object forKey:(NSString *)key;
+ (id)objectForKey:(NSString *)key;

- (IBAction)changeWarpSetting:(id)sender;
- (IBAction)changeModifierSetting:(id)sender;

@end
