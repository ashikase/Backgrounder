/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
j* Last-modified: 2010-06-27 03:51:00
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


#import "PreferenceConstants.h"


static BOOL isFirmware3x = NO;

static BOOL backgroundingEnabled_ = NO;
static BGBackgroundingMethod backgroundingMethod_ = BGBackgroundingMethodBackgrounder;
static BOOL fallbackToNative_ = YES;

#define GSEventRef void *

//==============================================================================

@interface UIApplication (Private)
- (NSString *)displayIdentifier;
- (void)terminateWithSuccess;
@end

static void loadPreferences()
{
    NSString *displayId = [[UIApplication sharedApplication] displayIdentifier];

    // NOTE: System preferences are not accessible from App Store apps.
    //       A symlink to the preferences file is stored in /var/mobile,
    //       which *can* be accessed.
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/.backgrounderrc"];

    NSDictionary *prefs = [[defaults objectForKey:kOverrides] objectForKey:displayId];
    if (prefs == nil)
        prefs = [defaults objectForKey:kGlobal];
    
    // Backgrounding method
    id value = [prefs objectForKey:kBackgroundingMethod];
    if ([value isKindOfClass:[NSNumber class]])
        backgroundingMethod_ = (BGBackgroundingMethod)[value integerValue];

    // Fallback to native
    value = [prefs objectForKey:kFallbackToNative];
    if ([value isKindOfClass:[NSNumber class]])
        fallbackToNative_ = [value boolValue];
}

//==============================================================================

// Callback
static void toggleBackgrounding(int signal)
{
    if (backgroundingMethod_ != BGBackgroundingMethodOff)
        backgroundingEnabled_ = !backgroundingEnabled_;
}

//==============================================================================

// NOTE: This struct comes from UIApplication; note that this declaration is incomplete.

// // Firmware 3.0 - 3.2.
typedef struct {
    unsigned isActive : 1;
    unsigned isSuspended : 1;
    unsigned isSuspendedEventsOnly : 1;
    unsigned isLaunchedSuspended : 1;
    unsigned isHandlingURL : 1;
    unsigned isHandlingRemoteNotification : 1;
    unsigned statusBarMode : 8;
    unsigned statusBarShowsProgress : 1;
    unsigned blockInteractionEvents : 4;
    unsigned forceExit : 1;
    unsigned receivesMemoryWarnings : 1;
    unsigned showingProgress : 1;
    unsigned receivesPowerMessages : 1;
    unsigned launchEventReceived : 1;
    unsigned isAnimatingSuspensionOrResumption : 1;
    unsigned isSuspendedUnderLock : 1;
    unsigned shouldExitAfterSendSuspend : 1;
    // ...
} UIApplicationFlags3x;

// Firmware 4.0
typedef struct {
    unsigned isActive : 1;
    unsigned isSuspended : 1;
    unsigned isSuspendedEventsOnly : 1;
    unsigned isLaunchedSuspended : 1;
    unsigned calledNonSuspendedLaunchDelegate : 1;
    unsigned isHandlingURL : 1;
    unsigned isHandlingRemoteNotification : 1;
    unsigned isHandlingLocalNotification : 1;
    unsigned statusBarShowsProgress : 1;
    unsigned statusBarRequestedStyle : 4;
    unsigned statusBarHidden : 1;
    unsigned blockInteractionEvents : 4;
    unsigned receivesMemoryWarnings : 1;
    unsigned showingProgress : 1;
    unsigned receivesPowerMessages : 1;
    unsigned launchEventReceived : 1;
    unsigned isAnimatingSuspensionOrResumption : 1;
    unsigned isResuming : 1;
    unsigned isSuspendedUnderLock : 1;
    unsigned isRunningInTaskSwitcher : 1;
    unsigned shouldExitAfterSendSuspend : 1;
    // ...
} UIApplicationFlags4x;


%hook UIApplication

%group GMethodAll

// Overriding this method prevents the application from quitting on suspend
// NOTE: UIApplication's default implementation of applicationSuspend: simply
//       sets _applicationFlags.shouldExitAfterSendSuspend to YES
- (void)applicationSuspend:(GSEventRef)event
{
    if (!backgroundingEnabled_ || backgroundingMethod_ != BGBackgroundingMethodBackgrounder) {
        %orig;

        if (!backgroundingEnabled_
                && (backgroundingMethod_ != BGBackgroundingMethodBackgrounder || !fallbackToNative_)) {
            // Application should terminate on suspend; make certain that it does
            // FIXME: Determine if there is any benefit of using shouldExitAfterSendSuspend
            //        over forceExit.
            if (isFirmware3x) {
                UIApplicationFlags3x &_applicationFlags = MSHookIvar<UIApplicationFlags3x>(self, "_applicationFlags");
                _applicationFlags.shouldExitAfterSendSuspend = YES;
            } else {
                UIApplicationFlags4x &_applicationFlags = MSHookIvar<UIApplicationFlags4x>(self, "_applicationFlags");
                _applicationFlags.shouldExitAfterSendSuspend = YES;
            }
        }
    }
}

%end

%group GMethodAll_SuspendSettings

// Used by certain applications, such as Mail and Phone, instead of applicationSuspend:
- (BOOL)applicationSuspend:(GSEventRef)event settings:(id)settings
{
    // NOTE: The return value for this method appears to not be used;
    //       perhaps a leftover from 1.x/2.x?
    // FIXME: Confirm this.
    BOOL ret = NO;

    if (!backgroundingEnabled_ || backgroundingMethod_ != BGBackgroundingMethodBackgrounder) {
        ret = %orig;

        if (!backgroundingEnabled_
                && (backgroundingMethod_ != BGBackgroundingMethodBackgrounder || !fallbackToNative_)) {
            // Application should terminate on suspend; make certain that it does
            if (isFirmware3x) {
                // NOTE: The shouldExitAfterSendSuspend flag appears to be ignored when
                //       this alternative method is called; resort to more "drastic"
                //       measures.
                UIApplicationFlags3x &_applicationFlags = MSHookIvar<UIApplicationFlags3x>(self, "_applicationFlags");
                _applicationFlags.forceExit = YES;
            } else {
                // FIXME: Not certain if this is the best method for forcing termination.
                [self terminateWithSuccess];
            }
        }
    }

    return ret;
}

%end

%end // UIApplication

//==============================================================================

%group GMethodBackgrounder
// NOTE: Only hooked for BGBackgroundingMethodBackgrounder

%hook UIApplication

// Prevent execution of application's on-suspend method
// NOTE: Normally this method does nothing; only system apps can overrride
- (void)applicationWillSuspend
{
    if (!backgroundingEnabled_)
        %orig;
}

// Prevent execution of application's on-resume methods
// NOTE: Normally this method does nothing; only system apps can overrride
- (void)applicationDidResume
{
    if (!backgroundingEnabled_)
        %orig;
}

%end

%end // GMethodBackgrounder

//==============================================================================

%hook AppDelegate
// NOTE: Only hooked for BGBackgroundingMethodBackgrounder

%group GMethodBackgrounder_Resign

// Delegate method
- (void)applicationWillResignActive:(id)application
{
    if (!backgroundingEnabled_)
        %orig;
}

%end

%group GMethodBackgrounder_Become

// Delegate method
- (void)applicationDidBecomeActive:(id)application
{
    if (!backgroundingEnabled_)
        %orig;
}

%end

%end // AppDelegate

//==============================================================================

%hook UIApplication

- (void)_loadMainNibFile
{
    // NOTE: This method always gets called, even if no NIB files are used.
    //       This method was chosen as it is called after the application
    //       delegate has been set.
    // NOTE: If an application overrides this method (unlikely, but possible),
    //       this extension's hooks will not be installed.
    %orig;

    // Load preferences to determine backgrounding method to use
    loadPreferences();

    // NOTE: Application class may be a subclass of UIApplication (and not UIApplication itself)
    Class $UIApplication = [self class];
    %init(GMethodAll, UIApplication = $UIApplication);
    if ([self respondsToSelector:@selector(applicationSuspend:settings:)])
        %init(GMethodAll_SuspendSettings, UIApplication = $UIApplication);

    if (backgroundingMethod_ == BGBackgroundingMethodBackgrounder) {
        %init(GMethodBackgrounder, UIApplication = $UIApplication);

        // NOTE: Not every app implements the following two methods
        id delegate = [self delegate];
        Class $AppDelegate = delegate ? [delegate class] : [self class];
        if ([delegate respondsToSelector:@selector(applicationWillResignActive:)])
            %init(GMethodBackgrounder_Resign, AppDelegate = $AppDelegate);
        if ([delegate respondsToSelector:@selector(applicationDidBecomeActive:)])
            %init(GMethodBackgrounder_Become, AppDelegate = $AppDelegate);
    }
}

%end

//==============================================================================

void initApplicationHooks()
{
    Class $UIApplication = objc_getClass("UIApplication");
    isFirmware3x = (class_getInstanceMethod($UIApplication, @selector(applicationState)) == NULL);

    %init;

    // Setup action to take upon receiving toggle signal from SpringBoard
    // NOTE: Done this way as the application hooks *must* be installed in
    //       the UIApplication process, not the SpringBoard process
    // FIXME: Find alternative method of telling application to background
    //        so that blacklisted apps do not need to be hooked.
    //        (Signal must be caught, or application will be killed).
    sigset_t block_mask;
    sigfillset(&block_mask);
    struct sigaction action;
    action.sa_handler = toggleBackgrounding;
    action.sa_mask = block_mask;
    action.sa_flags = 0;
    sigaction(SIGUSR1, &action, NULL);
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
