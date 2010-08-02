/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-08-01 19:50:31
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

@interface SBIcon (Firmware32x)
+ (CGSize)defaultIconImageSize;
@end

// Firmware >= 4.0
@interface SBProcess : NSObject
@property(readonly, assign) int pid;
@end

// Firmware >= 4.0
@interface SBApplication (Firmware4x)
@property(retain) SBProcess *process;
- (void)setSuspendType:(int)type;
- (int)_suspensionType;
@end

// Firmware >= 4.0
@interface SBIconModel (Firmware4x)
- (id)leafIconForIdentifier:(id)identifier; 
@end

@interface UIModalView : UIView
@property(nonatomic,copy) NSString *title;
@end

@interface UIApplication (Private)
- (void)addStatusBarImageNamed:(id)named;
- (void)removeStatusBarImageNamed:(id)named;
@end

struct GSEvent;

// GraphicsServices
extern "C" {
    extern CFStringRef kGSUnifiedIPodCapability;
    Boolean GSSystemHasCapability(CFStringRef capability);
}

static BOOL isFirmware3x = NO;
static NSMutableArray *appsSupportingMultitask_ = nil;

//==============================================================================

// Import constants for preference keys
#import "PreferenceConstants.h"

// Store a copy of the global preferences in memory
static NSDictionary *globalPrefs_ = nil;

// Store a list of apps that override the default preferences
static NSArray *appsWithOverrides_ = nil;

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
            globalPrefs_ = [NSDictionary dictionaryWithDictionary:(NSDictionary *)propList];
        CFRelease(propList);
    }
    if (globalPrefs_ == nil)
        // Use default values
        globalPrefs_ = [defaults objectForKey:kGlobal];
    [globalPrefs_ retain];

    // Try reading user's overrides preference settings
    propList = CFPreferencesCopyAppValue((CFStringRef)kOverrides, appId);
    if (propList != NULL) {
        if (CFGetTypeID(propList) == CFDictionaryGetTypeID())
            appsWithOverrides_ = [(NSDictionary *)propList allKeys];
        CFRelease(propList);
    }
    if (appsWithOverrides_ == nil) {
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
    [appsWithOverrides_ retain];
}

static id objectForKey(NSString *key, NSString *displayId)
{
    NSDictionary *prefs = nil;
    if ([appsWithOverrides_ containsObject:displayId]) {
        // This application does not use the default preferences
        CFPropertyListRef propList = CFPreferencesCopyAppValue((CFStringRef)kOverrides, CFSTR(APP_ID));
        if (propList != NULL) {
            if (CFGetTypeID(propList) == CFDictionaryGetTypeID())
                prefs = [(NSDictionary *)propList objectForKey:displayId];
            CFRelease(propList);
        }
    } else {
        // Use the default preferences
        prefs = globalPrefs_;
    }

    // Retrieve the value for the specified key
    id value = [prefs objectForKey:key];
    if (value == nil) {
        // Key may not have existed in previous version; check default global values
        NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:
            @"/Applications/Backgrounder.app/Defaults.plist"];
        value = [[defaults objectForKey:kGlobal] objectForKey:key];
    }

    return value;
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
    NSInteger ret = 0;

    id value = objectForKey(key, displayId);
    if ([value isKindOfClass:[NSNumber class]])
        ret = [value integerValue];

    if ([key isEqualToString:kBackgroundingMethod]) {
        if ([displayId isEqualToString:@APP_ID]) {
            // Do not allow Backgrounder preferences app to be backgrounded
            ret = BGBackgroundingMethodOff;
        } else if (ret == BGBackgroundingMethodAutoDetect) {
            // Use Native backgrounding method if supported, Backgrounder otherwise
            ret = (isFirmware3x || ![appsSupportingMultitask_ containsObject:displayId]) ?
                BGBackgroundingMethodBackgrounder : BGBackgroundingMethodNative;
        }
    }

    return ret;
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

static NSMutableArray *enabledApps_ = nil;
static NSMutableArray *appsPermittedToRelaunch_ = nil;

@interface UIView (Geometry)
@property(assign) CGPoint origin;
@end

static void setBadgeVisible(SBApplication *app, BOOL visible)
{
    NSString *identifier = [app displayIdentifier];

    // Update the app's SpringBoard icon to indicate if backgrounding is enabled
    SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
    SBApplicationIcon *icon = isFirmware3x ?
        [iconModel iconForDisplayIdentifier:identifier] : [iconModel leafIconForIdentifier:identifier];

    // Remove any existing badge
    // NOTE: Icon may already have a badge due to fall back to native option
    [[icon viewWithTag:1000] removeFromSuperview];

    if (visible) {
        // Determine origin for badge based on icon image size
        // NOTE: Default icon image sizes: iPhone/iPod: 59x62, iPad: 74x76 
        CGPoint point;
        Class $SBIcon = objc_getClass("SBIcon");
        if ([$SBIcon respondsToSelector:@selector(defaultIconImageSize)]) {
            // Determine position for badge (relative to lower left corner of icon)
            CGSize size = [$SBIcon defaultIconImageSize];
            point = CGPointMake(-12.0f, size.height - 23.0f);
        } else {
            // Fall back to hard-coded values (for firmware < 3.2, iPhone/iPod only)
            point = CGPointMake(-12.0f, 39.0f);
        }

        // Create and add badge
        BOOL isBackgrounderMethod = integerForKey(kBackgroundingMethod, identifier) == BGBackgroundingMethodBackgrounder
            && [enabledApps_ containsObject:identifier];
        NSString *fileName = isBackgrounderMethod ? @"Backgrounder_Badge.png" : @"Backgrounder_NativeBadge.png";
        UIImageView *badgeView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:fileName]];
        badgeView.tag = 1000;
        badgeView.origin = point;
        [icon addSubview:badgeView];
        [badgeView release];
    }
}

static void setStatusBarIndicatorVisible(SBApplication *app, BOOL visible)
{
    if (app == [SBWActiveDisplayStack topApplication]) {
        // Remove any existing indicator
        // NOTE: For iOS 4.0+, this code requires phoenix3200's libstatusbar
        //       extension to be present; otherwise will fail with a warning
        //       in syslog.
        UIApplication *springBoard = [UIApplication sharedApplication];
        [springBoard removeStatusBarImageNamed:@"Backgrounder"];
        [springBoard removeStatusBarImageNamed:@"Backgrounder_Native"];

        if (visible) {
            NSString *identifier = [app displayIdentifier];
#ifdef FALLBACK_INDICATORS
            BOOL isBackgrounderMethod = integerForKey(kBackgroundingMethod, identifier) == BGBackgroundingMethodBackgrounder
                && [enabledApps_ containsObject:identifier];
#else
            BOOL isBackgrounderMethod = integerForKey(kBackgroundingMethod, identifier) == BGBackgroundingMethodBackgrounder;
#endif
            NSString *itemName = isBackgrounderMethod ? @"Backgrounder" : @"Backgrounder_Native";
            [springBoard addStatusBarImageNamed:itemName];
        }
    }
}

// NOTE: Validity of parameters are not checked; use with caution.
static void setBackgroundingEnabled(SBApplication *app, BOOL enable)
{
    NSString *identifier = [app displayIdentifier];

    // NOTE: Passing 0 or -1 to kill could be potentially disastrous.
    int pid = isFirmware3x ? [app pid] : [[app process] pid];
    if (pid > 0)
        // FIXME: If the target application does not have the Backgrounder
        //        hooks enabled, this will cause it to exit abnormally
        kill(pid, SIGUSR1);

    // Store the new backgrounding status of the application
    if (enable)
        [enabledApps_ addObject:identifier];
    else
        [enabledApps_ removeObject:identifier];

#ifdef FALLBACK_INDICATORS
    // NOTE: Indicators will also be shown if fall back to native option is enabled
    BOOL showIndicator = enable
        || (integerForKey(kBackgroundingMethod, identifier) == BGBackgroundingMethodBackgrounder
                && boolForKey(kFallbackToNative, identifier)
                && pid > 0);
#else
    BOOL showIndicator = enable;
#endif

    // Update badge (if necessary)
    if (boolForKey(kBadgeEnabled, identifier))
        setBadgeVisible(app, showIndicator);

    // Update status bar indicator (if necessary)
    if (boolForKey(kStatusBarIconEnabled, identifier))
        setStatusBarIndicatorVisible(app, showIndicator);
}

//==============================================================================

@interface SpringBoard (BackgrounderInternal)
- (void)suspendAppWithDisplayIdentifier:(NSString *)displayId;
- (void)dismissBackgrounderFeedback;
@end

// The alert window displays instructions when the home button is held down
static BackgrounderAlertItem *alert_ = nil;

static NSString *displayIdToSuspend_ = nil;
static BOOL shouldSuspend_ = NO;

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    // NOTE: SpringBoard creates four stacks at startup
    displayStacks = [[NSMutableArray alloc] initWithCapacity:4];

    if (!isFirmware3x)
    // Create array to mark apps that support iOS4's native multitasking
    appsSupportingMultitask_ = [[NSMutableArray alloc] init];

    // Call original implementation
    %orig;

    // Load extension preferences
    loadPreferences();

    // Create array to track apps with backgrounding enabled
    enabledApps_ = [[NSMutableArray alloc] init];

    // Create array to mark apps that are allowed to auto-relaunch
    appsPermittedToRelaunch_ = [[NSMutableArray alloc] init];
}

- (void)dealloc
{
    [displayIdToSuspend_ release];
    [appsPermittedToRelaunch_ release];
    [enabledApps_ release];
    [appsSupportingMultitask_ release];
    [displayStacks release];

    %orig;
}

- (void)menuButtonUp:(GSEventRef)event
{
    %orig;

    if (shouldSuspend_) {
        // Dismiss backgrounder message and suspend the application
        // NOTE: Only used when invocation method is MenuHoldShort
        [self performSelector:@selector(dismissBackgrounderFeedbackAndSuspend) withObject:nil];
        shouldSuspend_ = NO;
    }
}

- (void)lockButtonUp:(GSEventRef)event
{
    if (shouldSuspend_) {
        // Reset the lock button state
        if (isFirmware3x)
            [self _unsetLockButtonBearTrap];
        [self _setLockButtonTimer:nil];

        // Dismiss backgrounder message and suspend the application
        // NOTE: Only used when invocation method is LockHoldShort
        [self performSelector:@selector(dismissBackgrounderFeedbackAndSuspend) withObject:nil];
        shouldSuspend_ = NO;
    } else {
        %orig;
    }
}

- (void)frontDisplayDidChange
{
    %orig;

    if ([SBWActiveDisplayStack topApplication] == nil)
        // SpringBoard is visible; remove any status bar indicator
        setStatusBarIndicatorVisible(nil, NO);
}

%new(v@:)
- (void)invokeBackgrounder
{
    [self invokeBackgrounderAndAutoSuspend:YES];
}

%new(v@:)
- (void)invokeBackgrounderAndAutoSuspend:(BOOL)autoSuspend
{
    if (displayIdToSuspend_ != nil)
        // Previous invocation has not finished
        return;

    id app = [SBWActiveDisplayStack topApplication];
    NSString *identifier = [app displayIdentifier];
    if (app && integerForKey(kBackgroundingMethod, identifier) != BGBackgroundingMethodOff) {
        BOOL isEnabled = [enabledApps_ containsObject:identifier];
        [self setBackgroundingEnabled:(!isEnabled) forDisplayIdentifier:identifier];

        // Create a simple popup message
        NSString *status = [NSString stringWithFormat:@"Backgrounding %s", (isEnabled ? "Disabled" : "Enabled")];
        alert_ = [[objc_getClass("BackgrounderAlertItem") alloc] initWithTitle:status message:nil];

        // ... and display it
        SBAlertItemsController *controller = [objc_getClass("SBAlertItemsController") sharedInstance];
        [controller activateAlertItem:alert_];

        if (boolForKey(kMinimizeOnToggle, identifier))
            // Record identifer of application for suspension later
            displayIdToSuspend_ = [identifier copy];

        if (autoSuspend)
            // After delay, simulate menu button tap to suspend current app
            [self performSelector:@selector(dismissBackgrounderFeedbackAndSuspend) withObject:nil afterDelay:0.7f];
        else
            // NOTE: Only used when invocation method is MenuHoldShort or LockHoldShort
            shouldSuspend_ = YES;
    }
}

%new(v@:)
- (void)cancelPreviousBackgrounderInvocation
{
    if (alert_ != nil) {
        // Backgrounder was invoked (feedback exists)
        alert_.alertSheet.title = @"Cancelled!";

        // Undo change to backgrounding status of current application
        id app = [SBWActiveDisplayStack topApplication];
        if (app) {
            NSString *identifier = [app displayIdentifier];
            BOOL isEnabled = [enabledApps_ containsObject:identifier];
            [self setBackgroundingEnabled:(!isEnabled) forDisplayIdentifier:identifier];
        }

        // Reset related variables
        [displayIdToSuspend_ release];
        displayIdToSuspend_ = nil;

        // Dismiss feedback after short delay (else cancellation message will not be seen)
        [self performSelector:@selector(dismissBackgrounderFeedback) withObject:nil afterDelay:1.0f];
    }
}

%new(v@:c@)
- (void)setBackgroundingEnabled:(BOOL)enable forDisplayIdentifier:(NSString *)identifier
{
    if (integerForKey(kBackgroundingMethod, identifier) != BGBackgroundingMethodOff) {
        BOOL isEnabled = [enabledApps_ containsObject:identifier];
        if (isEnabled != enable) {
            // Tell the application to change its backgrounding status
            SBApplication *app = [[objc_getClass("SBApplicationController") sharedInstance]
                applicationWithDisplayIdentifier:identifier];
            setBackgroundingEnabled(app, enable);
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
    [alert_ dismiss];
    [alert_ release];
    alert_ = nil;
}

%new(v@:)
- (void)dismissBackgrounderFeedbackAndSuspend
{
    // Dismiss the message and suspend the application
    [self dismissBackgrounderFeedback];

    if (displayIdToSuspend_ != nil) {
        // Suspend the specified application
        [self suspendAppWithDisplayIdentifier:displayIdToSuspend_];

        // Reset related variables
        [displayIdToSuspend_ release];
        displayIdToSuspend_ = nil;
    }
}

%end

//==============================================================================

%hook SBApplication

- (void)launchSucceeded:(BOOL)unknownFlag
{
    NSString *identifier = [self displayIdentifier];

    NSInteger backgroundingMethod = integerForKey(kBackgroundingMethod, identifier);
    if (backgroundingMethod != BGBackgroundingMethodOff) {
        // NOTE: Display setting 0x2 is resume
        if ([self displaySetting:0x2]) {
            // Was restored from backgrounded state
            if (!boolForKey(kPersistent, identifier))
                setBackgroundingEnabled(self, NO);
            else if (boolForKey(kStatusBarIconEnabled, identifier))
#ifndef FALLBACK_INDICATORS
                if ([enabledApps_ containsObject:identifier])
#endif
                // Must re-add the indicator on resume
                setStatusBarIndicatorVisible(self, YES);
        } else {
            // Initial launch; check if this application is set to background at launch
            if (boolForKey(kEnableAtLaunch, identifier))
                setBackgroundingEnabled(self, YES);
#ifdef FALLBACK_INDICATORS
            else if (boolForKey(kStatusBarIconEnabled, identifier)
                    && backgroundingMethod == BGBackgroundingMethodBackgrounder
                    && boolForKey(kFallbackToNative, identifier))
                // Must add the initial indicator for "Native"
                setStatusBarIndicatorVisible(self, YES);
#endif
        }
    }

    %orig;
}

- (void)exitedAbnormally
{
    NSString *identifier = [self displayIdentifier];
    if ([enabledApps_ containsObject:identifier]
            || (integerForKey(kBackgroundingMethod, identifier) == BGBackgroundingMethodBackgrounder
                && boolForKey(kFallbackToNative, identifier)))
        // Allow app to relaunch (if it supports relaunching)
        [appsPermittedToRelaunch_ addObject:identifier];

    %orig;
}

- (void)exitedCommon
{
    // Application has exited (either normally or abnormally);
    // NOTE: The only time an app would exit while backgrounding is enabled
    //       is if it exited abnormally (e.g. crash) or if the "Native" method
    //       was in use and the app doesn't natively support backgrounding.
    NSString *identifier = [self displayIdentifier];
    if (integerForKey(kBackgroundingMethod, identifier) != BGBackgroundingMethodOff)
        setBackgroundingEnabled(self, NO);

    %orig;
}

- (void)deactivate
{
    NSString *identifier = [self displayIdentifier];
    BOOL isEnabled = [enabledApps_ containsObject:identifier];
    BOOL isBackgrounderMethod =
        (integerForKey(kBackgroundingMethod, identifier) == BGBackgroundingMethodBackgrounder);
    BOOL shouldFallback = isBackgrounderMethod && boolForKey(kFallbackToNative, identifier);

    BOOL flag = NO;
    if (isEnabled && isBackgrounderMethod) {
        // Temporarily enable the eventOnly flag to prevent the applications's views
        // from being deallocated.
        // NOTE: Credit for this goes to phoenix3200 (author of Music Controls, http://phoenix-dev.com/)
        // NOTE: This prevents applicationSuspend: from being called.
        // FIXME: Run a trace on deactivate to determine why this works.
        flag = [self deactivationSetting:0x1];
        [self setDeactivationSetting:0x1 flag:YES];
    }

    // Firmware 4.0
    BOOL shouldQuit = !isFirmware3x && !isEnabled && !shouldFallback;
    int suspendType = 0;
    if (shouldQuit) {
        // App should quit
        suspendType = [self _suspensionType];
        [self setSuspendType:0];
    }

    %orig;

    // Firmware 4.0
    if (shouldQuit)
        // Restore suspension type
        [self setSuspendType:suspendType];

    if (isEnabled && isBackgrounderMethod)
        // Must disable the eventOnly flag before returning, or else the application
        // will remain in the event-only display stack and prevent SpringBoard from
        // operating properly.
        // NOTE: This is the continuation of phoenix3200's fix
        [self setDeactivationSetting:0x1 flag:flag];

#ifdef FALLBACK_INDICATORS
    // NOTE: For apps set to fall back to native, the native badge will not be
    //       displayed until the backgrounding state of the app has been toggled
    //       on and off. This workaround ensures that a native badge is added.
    // FIXME: Find a better way to do this.
    if (!isEnabled && shouldFallback)
        setBadgeVisible(self, YES);
#endif
}

- (void)deactivated
{
    %orig;

    if ([enabledApps_ containsObject:[self displayIdentifier]])
        // If a notification is received while the device is locked, the app's
        // GUI will get "stuck" and will no longer respond to the home button.
        // Prevent this by hiding the app's context view upon deactivation.
        // NOTE: Credit for this one also goes to phoenix3200
        [[self contextHostView] setHidden:YES];
}

// NOTE: Observed types:
//         0: Launch
//         1: Resume
//         2: Deactivation
//         3: Termination
- (void)_startWatchdogTimerType:(int)type
{
    if (type != 3 || ![enabledApps_ containsObject:[self displayIdentifier]])
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
    if (!exitedAbnormally) {
        // Application exited normally (presumably by user); prevent auto-relaunch
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

static BOOL shouldAutoLaunch(NSString *identifier, BOOL initialCheck, BOOL origValue)
{
    // NOTE: This method determines both whether an application should be
    //       launched at startup and whether it should be relaunched when
    //       terminated.
    // FIXME: Support for auto-boot flag.

    BOOL ret = NO;

    if (initialCheck) {
        NSInteger backgroundingMethod = integerForKey(kBackgroundingMethod, identifier);
        if (backgroundingMethod == BGBackgroundingMethodNative
            || (backgroundingMethod == BGBackgroundingMethodBackgrounder && boolForKey(kFallbackToNative, identifier)))
            // Allow launch at boot
            ret = origValue;
    } else {
        if ([appsPermittedToRelaunch_ containsObject:identifier]) {
            // Allow relaunch
            ret = origValue;

            // Remove from list
            [appsPermittedToRelaunch_ removeObject:identifier];
        }
    }

    return ret;
}

// NOTE: Only hooked for firmware 3.1 - 3.2
%group GFirmware31x

%hook SBApplication

- (BOOL)_shouldAutoLaunchOnBoot:(BOOL)initialCheck
{
    // NOTE: Meaning of passed parameter is a guess, based on disassembly.
    // FIXME: Confirm meaning.
    return shouldAutoLaunch([self displayIdentifier], initialCheck, %orig);
}

%end

%end // GFirmware31x

// NOTE: Only hooked for firmware >= 4.0
%group GFirmware4x

%hook SBApplication

- (BOOL)_shouldAutoLaunchOnBootOrInstall:(BOOL)initialCheck
{
    // NOTE: Meaning of passed parameter is a guess, based on disassembly.
    // FIXME: Confirm meaning.
    return shouldAutoLaunch([self displayIdentifier], initialCheck, %orig);
}

// NOTE: Hooked to determine if app supports native multitasking.
- (id)initWithBundleIdentifier:(id)bundleIdentifier roleIdentifier:(id)identifier path:(id)path bundle:(id)bundle
    infoDictionary:(id)dictionary isSystemApplication:(BOOL)application signerIdentity:(id)identity
    provisioningProfileValidated:(BOOL)validated
{
    id ret = %orig;

    BOOL supportsMultitask = NO;

    // Check if app was built with 4.x SDK
    id value = [dictionary objectForKey:@"DTSDKName"];
    if ([value isKindOfClass:[NSString class]]) {
        if ([(NSString *)value hasPrefix:@"iphoneos4"]) {
            // Check if app is set to exit on suspend
            BOOL exitsOnSuspend = NO;
            value = [dictionary objectForKey:@"UIApplicationExitsOnSuspend"];
            if ([value isKindOfClass:[NSNumber class]])
                exitsOnSuspend = [(NSNumber *)value boolValue];

            // App supports multitask if it does not exit on suspend
            supportsMultitask = !exitsOnSuspend;
        }
    }

    // NOTE: App may have been built with 3.x SDK but still supports multitask;
    //       check if app supports any of the allowed background modes.
    //       (One known example is TomTom.)
    if (!supportsMultitask) {
        id value = [dictionary objectForKey:@"UIBackgroundModes"];
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray *array = (NSArray *)value;
            supportsMultitask = [array containsObject:@"audio"]
                || [array containsObject:@"location"]
                || [array containsObject:@"voip"]
                || [array containsObject:@"continuous"];
        }
    }

    if (supportsMultitask)
        // App supports multitasking
        [appsSupportingMultitask_ addObject:[self displayIdentifier]];

    return ret;
}

%end

%end // GFirmware4x

//==============================================================================

void initSpringBoardHooks()
{
    %init;

    // Determine firmware version
    Class $SBApplication = objc_getClass("SBApplication");
    isFirmware3x = (class_getInstanceMethod($SBApplication, @selector(pid)) != NULL);

    // Load firmware-specific hooks
    if (isFirmware3x) {
        if (class_getInstanceMethod($SBApplication, @selector(_shouldAutoLaunchOnBoot:)) == NULL)
            // Firmware < 3.1
            %init(GFirmware30x);
        else
            // Firmware 3.1 - 3.2
            %init(GFirmware31x);
    } else {
        // Firmware >= 4.0
        %init(GFirmware4x);
    }

    // Initialize simple notification popup
    initSimplePopup();
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
