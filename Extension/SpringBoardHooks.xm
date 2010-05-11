/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-05-08 04:05:59
 */

/**
 * Copyright (C) 2008-2010  Lance Fetters (aka. ashikase)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#import "SpringBoardHooks.h"

#import <CoreFoundation/CoreFoundation.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SpringBoard.h>

#import "BackgrounderActivator.h"
#import "SimplePopup.h"

@interface UIModalView : UIView
@property(nonatomic,copy) NSString *title;
@end

struct GSEvent;

// GraphicsServices
extern "C" {
    extern CFStringRef kGSUnifiedIPodCapability;
    Boolean GSSystemHasCapability(CFStringRef capability);
}

//==============================================================================

// Import constants for preference keys
#import "PreferenceConstants.h"

// Store a copy of the global preferences in memory
static NSDictionary *globalPrefs = nil;

// Store a list of apps that override the default preferences
static NSArray *appsWithOverrides = nil;

static void loadPreferences()
{
    CFStringRef appId = CFSTR(APP_ID);

    // Read in default values for preference settings
    // NOTE: The values used depends on whether or not this device has the
    //       "unified iPod" capability. This capability cannot be determined 
    //       until after SBPlatformController is initialized, which happens in
    //       applicationDidFinishLaunching:.
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:
        @"/Applications/Backgrounder.app/Defaults.plist"];

    // Try reading user's global preference settings
    CFPropertyListRef propList = CFPreferencesCopyAppValue((CFStringRef)kGlobal, appId);
    if (propList != NULL) {
        if (CFGetTypeID(propList) == CFDictionaryGetTypeID())
            globalPrefs = [NSDictionary dictionaryWithDictionary:(NSDictionary *)propList];
        CFRelease(propList);
    }
    if (globalPrefs == nil)
        // Use default values
        globalPrefs = [defaults objectForKey:kGlobal];
    [globalPrefs retain];

    // Try reading user's overrides preference settings
    propList = CFPreferencesCopyAppValue((CFStringRef)kOverrides, appId);
    if (propList != NULL) {
        if (CFGetTypeID(propList) == CFDictionaryGetTypeID())
            appsWithOverrides = [(NSDictionary *)propList allKeys];
        CFRelease(propList);
    }
    if (appsWithOverrides == nil) {
        // Use default values
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:
            [defaults objectForKey:kOverrides]];

        // Filter out applications that do not exist on this device
        SBApplicationController *appCont = [objc_getClass("SBApplicationController") sharedInstance];
        for (NSString *displayId in [dict allKeys])
            if ([appCont applicationWithDisplayIdentifier:displayId] == nil)
                [dict removeObjectForKey:displayId];

        // Write a copy of the default values to disk
        // NOTE: This is done as the values are not cached; they are later
        //       accessed from disk, and thus must be available there.
        CFPreferencesSetAppValue((CFStringRef)kOverrides, dict, appId);
        CFPreferencesSynchronize(appId, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    }
    [appsWithOverrides retain];
}

static id objectForKey(NSString *key, NSString *displayId)
{
    NSDictionary *prefs = nil;
    if ([appsWithOverrides containsObject:displayId]) {
        // This application does not use the default preferences
        CFPropertyListRef propList = CFPreferencesCopyAppValue((CFStringRef)kOverrides, CFSTR(APP_ID));
        if (propList != NULL) {
            if (CFGetTypeID(propList) == CFDictionaryGetTypeID())
                prefs = [(NSDictionary *)propList objectForKey:displayId];
            CFRelease(propList);
        }
    } else {
        // Use the default preferences
        prefs = globalPrefs;
    }

    return [prefs objectForKey:key];
}

static BOOL boolForKey(NSString *key, NSString *displayId)
{
    BOOL ret = NO;

    id value = objectForKey(key, displayId);
    if ([value isKindOfClass:[NSNumber class]])
        ret = [value boolValue];

    return ret;
}

static NSInteger integerForKey(NSString *key, NSString *displayId)
{
    NSInteger ret = NO;

    id value = objectForKey(key, displayId);
    if ([value isKindOfClass:[NSNumber class]])
        ret = [value integerValue];

    return ret;
}

//==============================================================================

@interface UIView (Geometry)
@property(assign) CGPoint origin;
@end

static void showBadgeForDisplayIdentifier(NSString *identifier)
{
    // Update the application's SpringBoard icon to indicate that it is running
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
    if (![icon viewWithTag:1000]) {
        // Icon does not yet have a badge

        // Determine position for badge (relative to lower left corner of icon)
        CGPoint point;
        UIImageView *imageView = MSHookIvar<UIImageView *>(icon, "_image");
        if (imageView != nil) {
            CGRect frame = imageView.frame;
            point = CGPointMake(frame.origin.x + -12.0f, frame.origin.y + frame.size.height - 21.0f);
        } else {
            // Fall back to hard-coded values
            point = CGPointMake(-12.0f, 39.0f);
        }

        // Create and add badge
        UIImageView *badgeView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Backgrounder_Badge.png"]];
        badgeView.tag = 1000;
        badgeView.origin = point;
        [icon addSubview:badgeView];
        [badgeView release];
    }

}

//==============================================================================

NSMutableArray *displayStacks = nil;

// Display stack names
#define SBWPreActivateDisplayStack        [displayStacks objectAtIndex:0]
#define SBWActiveDisplayStack             [displayStacks objectAtIndex:1]
#define SBWSuspendingDisplayStack         [displayStacks objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack [displayStacks objectAtIndex:3]

%hook SBDisplayStack

- (id)init
{
    id stack = %orig;
    [displayStacks addObject:stack];
    return stack;
}

- (void)dealloc
{
    [displayStacks removeObject:self];
    %orig;
}

%end

//==============================================================================

// The alert window displays instructions when the home button is held down
static BackgrounderAlertItem *alert = nil;

//==============================================================================

@interface SpringBoard (BackgrounderInternal)
- (void)suspendAppWithDisplayIdentifier:(NSString *)displayId;
- (void)dismissBackgrounderFeedback;
@end

static NSMutableArray *activeApps = nil;
static NSMutableArray *bgEnabledApps = nil;

static NSString *displayIdToSuspend = nil;
static BOOL shouldSuspend = NO;

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    // NOTE: SpringBoard creates four stacks at startup
    displayStacks = [[NSMutableArray alloc] initWithCapacity:4];

    // Call original implementation
    %orig;

    // Load extension preferences
    loadPreferences();

    // NOTE: The initial capacity value was chosen to hold the default active
    //       apps (MobilePhone and MobileMail) plus two others
    activeApps = [[NSMutableArray alloc] initWithCapacity:4];
    bgEnabledApps = [[NSMutableArray alloc] initWithCapacity:2];

    // Create the libactivator event listener
    [BackgrounderActivator load];
}

- (void)dealloc
{
    [displayIdToSuspend release];
    [bgEnabledApps release];
    [activeApps release];
    [displayStacks release];

    %orig;
}

- (void)menuButtonUp:(GSEventRef)event
{
    %orig;

    if (shouldSuspend) {
        // Dismiss backgrounder message and suspend the application
        // NOTE: Only used when invocation method is MenuHoldShort
        [self performSelector:@selector(dismissBackgrounderFeedbackAndSuspend) withObject:nil];
        shouldSuspend = NO;
    }
}

- (void)lockButtonUp:(GSEventRef)event
{
    if (shouldSuspend) {
        // Reset the lock button state
        [self _unsetLockButtonBearTrap];
        [self _setLockButtonTimer:nil];

        // Dismiss backgrounder message and suspend the application
        // NOTE: Only used when invocation method is LockHoldShort
        [self performSelector:@selector(dismissBackgrounderFeedbackAndSuspend) withObject:nil];
        shouldSuspend = NO;
    } else {
        %orig;
    }
}

- (void)frontDisplayDidChange
{
    %orig;

    // NOTE: Always first try removing status bar indicator, as previous
    //       application may have had it enabled even if the current does not.
    SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
    [sbCont removeStatusBarItem:@"Backgrounder"];

    id app = [SBWActiveDisplayStack topApplication];
    if (app != nil) {
        NSString *identifier = [app displayIdentifier];
        if (boolForKey(kStatusBarIconEnabled, identifier) && [bgEnabledApps containsObject:identifier])
            [sbCont addStatusBarItem:@"Backgrounder"];
    }
}

%new(v@:)
- (void)invokeBackgrounder
{
    [self invokeBackgrounderAndAutoSuspend:YES];
}

%new(v@:)
- (void)invokeBackgrounderAndAutoSuspend:(BOOL)autoSuspend
{
    if (displayIdToSuspend != nil)
        // Previous invocation has not finished
        return;

    id app = [SBWActiveDisplayStack topApplication];
    NSString *identifier = [app displayIdentifier];
    if (app && integerForKey(kBackgroundingMethod, identifier) == BGBackgroundingMethodBackgrounder) {
        BOOL isEnabled = [bgEnabledApps containsObject:identifier];
        [self setBackgroundingEnabled:(!isEnabled) forDisplayIdentifier:identifier];

        // Create a simple popup message
        NSString *status = [NSString stringWithFormat:@"Backgrounding %s", (isEnabled ? "Disabled" : "Enabled")];
        alert = [[objc_getClass("BackgrounderAlertItem") alloc] initWithTitle:status message:nil];

        // ... and display it
        SBAlertItemsController *controller = [objc_getClass("SBAlertItemsController") sharedInstance];
        [controller activateAlertItem:alert];

        // Record identifer of application for later use
        displayIdToSuspend = [identifier copy];

        if (autoSuspend)
            // After delay, simulate menu button tap to suspend current app
            [self performSelector:@selector(dismissBackgrounderFeedbackAndSuspend) withObject:nil afterDelay:0.6f];
        else
            // NOTE: Only used when invocation method is MenuHoldShort or LockHoldShort
            shouldSuspend = YES;
    }
}

%new(v@:)
- (void)cancelPreviousBackgrounderInvocation
{
    if (alert != nil) {
        // Backgrounder was invoked (feedback exists)
        alert.alertSheet.title = @"Cancelled!";

        // Undo change to backgrounding status of current application
        id app = [SBWActiveDisplayStack topApplication];
        if (app) {
            NSString *identifier = [app displayIdentifier];
            BOOL isEnabled = [bgEnabledApps containsObject:identifier];
            [self setBackgroundingEnabled:(!isEnabled) forDisplayIdentifier:identifier];
        }

        // Reset related variables
        [displayIdToSuspend release];
        displayIdToSuspend = nil;

        // Dismiss feedback after short delay (else cancellation message will not be seen)
        [self performSelector:@selector(dismissBackgrounderFeedback) withObject:nil afterDelay:1.0f];
    }
}

%new(v@:c@)
- (void)setBackgroundingEnabled:(BOOL)enable forDisplayIdentifier:(NSString *)identifier
{
    if (integerForKey(kBackgroundingMethod, identifier) == BGBackgroundingMethodBackgrounder) {
        BOOL isEnabled = [bgEnabledApps containsObject:identifier];
        if (isEnabled != enable) {
            // Tell the application to change its backgrounding status
            SBApplication *app = [[objc_getClass("SBApplicationController") sharedInstance]
                applicationWithDisplayIdentifier:identifier];
            // FIXME: If the target application does not have the Backgrounder
            //        hooks enabled, this will cause it to exit abnormally
            kill([app pid], SIGUSR1);

            // Store the new backgrounding status of the application
            if (enable)
                [bgEnabledApps addObject:identifier];
            else
                [bgEnabledApps removeObject:identifier];
        }
    }
}

%new(v@:@)
- (void)suspendAppWithDisplayIdentifier:(NSString *)displayId
{
    // Is an application
    SBApplication *app = [[objc_getClass("SBApplicationController") sharedInstance]
        applicationWithDisplayIdentifier:displayId];
    if (app) {
        if ([SBWActiveDisplayStack containsDisplay:app]) {
            // Application is current app
            // NOTE: Must set animation flag for deactivation, otherwise
            //       application window does not disappear (reason yet unknown)
            [app setDeactivationSetting:0x2 flag:YES]; // animate

            // Remove from active display stack
            [SBWActiveDisplayStack popDisplay:app];
        }

        // Deactivate the application
        [SBWSuspendingDisplayStack pushDisplay:app];
    }
}

%new(v@:)
- (void)dismissBackgrounderFeedback
{
    // Hide and release alert window (may be nil)
    [alert dismiss];
    [alert release];
    alert = nil;
}

%new(v@:)
- (void)dismissBackgrounderFeedbackAndSuspend
{
    // Dismiss the message and suspend the application
    [self dismissBackgrounderFeedback];
    [self suspendAppWithDisplayIdentifier:displayIdToSuspend];

    // Reset related variables
    [displayIdToSuspend release];
    displayIdToSuspend = nil;
}

%end

//==============================================================================

%hook SBApplication

- (void)launchSucceeded:(BOOL)unknownFlag
{
    NSString *identifier = [self displayIdentifier];

    if ([activeApps containsObject:identifier]) {
        // Was restored from backgrounded state
        if (!boolForKey(kPersistent, identifier)) {
            // Tell the application to disable backgrounding
            kill([self pid], SIGUSR1);

            // Store the backgrounding status of the application
            [bgEnabledApps removeObject:identifier];
        } 
    } else {
        // Initial launch; check if this application is set to always background
        if (boolForKey(kEnableAtLaunch, identifier)) {
            // Tell the application to enable backgrounding
            kill([self pid], SIGUSR1);

            // Store the backgrounding status of the application
            [bgEnabledApps addObject:identifier];
        }

        // Track active status of application
        [activeApps addObject:identifier];
    }

    if (boolForKey(kBadgeEnabled, identifier))
        // NOTE: This is mainly to catch applications that start in the background
        showBadgeForDisplayIdentifier(identifier);

    %orig;
}

- (void)exitedAbnormally
{
    // NOTE: The only time an application would exit while backgrounding is
    //       enabled is if it exited abnormally (e.g. crash).
    [bgEnabledApps removeObject:[self displayIdentifier]];

    %orig;
}

- (void)exitedCommon
{
    // Application has exited (either normally or abnormally);
    // remove from active applications list
    NSString *identifier = [self displayIdentifier];
    [activeApps removeObject:identifier];

    if (boolForKey(kBadgeEnabled, identifier)) {
        // Update the SpringBoard icon to indicate that the app is not running
        // FIXME: Consider removing the kBadgeEnabled check as a method of optimization
        SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
        [[icon viewWithTag:1000] removeFromSuperview];
    }

    %orig;
}

- (void)deactivate
{
    NSString *identifier = [self displayIdentifier];
    BOOL isBackgrounded = [bgEnabledApps containsObject:identifier];

    if (boolForKey(kBadgeEnabled, identifier) && isBackgrounded)
        // In case badge has not been added yet, add now
        // FIXME: Confirm if this is still needed
        showBadgeForDisplayIdentifier(identifier);

    BOOL flag;
    if (isBackgrounded) {
        // Temporarily enable the eventOnly flag to prevent the applications's views
        // from being deallocated.
        // NOTE: Credit for this goes to phoenix3200 (author of Pandora Controls, http://phoenix-dev.com/)
        // FIXME: Run a trace on deactivate to determine why this works.
        flag = [self deactivationSetting:0x1];
        [self setDeactivationSetting:0x1 flag:YES];
    }

    %orig;

    if (isBackgrounded)
        // Must disable the eventOnly flag before returning, or else the application
        // will remain in the event-only display stack and prevent SpringBoard from
        // operating properly.
        // NOTE: This is the continuation of phoenix3200's fix
        [self setDeactivationSetting:0x1 flag:flag];
}

// NOTE: Observed types:
//         0: Launch
//         1: Resume
//         2: Deactivation
//         3: Termination
- (void)_startWatchdogTimerType:(int)type
{
    if (type != 3 || ![bgEnabledApps containsObject:[self displayIdentifier]])
        %orig;
}

%end

//==============================================================================

// NOTE: Only hooked for firmware < 3.1
%group GFirmware30x

%hook SBDisplayStack

// FIXME: Find a better way to prevent auto-launch of Phone and Mail
// NOTE: The SBDisable* preference keys are not used as they might get saved to
//       SpringBoard's preferences list, which is also used in Safe Mode.
- (void)pushDisplay:(id)display
{
    // NOTE: Activation setting 0x10000 is firstLaunchAfterBoot
    if (self == SBWActiveDisplayStack
        && [display activationSetting:0x10000]
        && integerForKey(kBackgroundingMethod, [display displayIdentifier]) != BGBackgroundingMethodNative) {
        // Backgrounding method is set to off or manual; prevent auto-launch at boot
        // NOTE: Activation settings will remain if not manually cleared
        [display clearActivationSettings];
        return;
    }

    %orig;
}

%end

%hook SBApplication

- (void)_relaunchAfterAbnormalExit:(BOOL)exitedAbnormally
{
    // NOTE: This method gets called by both exitedNormally and exitedAbnormally
    if (!exitedAbnormally
            && integerForKey(kBackgroundingMethod, [self displayIdentifier]) != BGBackgroundingMethodNative) {
        // Backgrounding method is set to off or manual; prevent auto-relaunch
        // NOTE: Only Phone and Mail are known to auto-relaunch

        // NOTE: Original method also calls _cancelAutoRelaunch, to cancel
        //       any outstanding delayed performSelector calls.
        [self _cancelAutoRelaunch];
    } else {
        %orig;
    }
}

%end

%end // GFirmware30x

// NOTE: Only hooked for firmware >= 3.1
%group GFirmware31x

%hook SBApplication

- (BOOL)_shouldAutoLaunchOnBoot:(BOOL)boot
{
    // NOTE: This method determines both whether an application should be
    //       launched at startup and whether it should be relaunched when
    //       terminated.

    // If backgrounding method is set to off or manual, prevent auto-(re)launch
    // NOTE: Only Phone and Mail are known to auto-(re)launch
    return (integerForKey(kBackgroundingMethod, [self displayIdentifier]) != BGBackgroundingMethodNative) ? NO : %orig;
}

%end

%end // GFirmware31x

//==============================================================================

void initSpringBoardHooks()
{
    %init;

    // Load firmware-specific hooks
    Class $SBApplication = objc_getClass("SBApplication");
    if (class_getInstanceMethod($SBApplication, @selector(_shouldAutoLaunchOnBoot:)) == NULL)
        // Firmware < 3.1
        %init(GFirmware30x);
    else
        // Firmware >= 3.1
        %init(GFirmware31x);

    // Initialize simple notification popup
    initSimplePopup();
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
