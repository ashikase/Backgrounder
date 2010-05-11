/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-05-04 23:47:02
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


static BOOL backgroundingEnabled = NO;
static int backgroundingMethod = 2;

#define GSEventRef void *

//==============================================================================

@interface UIApplication (Private)
- (NSString *)displayIdentifier;
@end

#define kGlobal                  @"global"
#define kOverrides               @"overrides"
#define kBackgroundingMethod     @"backgroundingMethod"

static void loadPreferences()
{
    NSString *displayId = [[UIApplication sharedApplication] displayIdentifier];

    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@APP_ID];
    NSDictionary *prefs = [[defaults objectForKey:kOverrides] objectForKey:displayId];
    if (prefs == nil)
        prefs = [defaults objectForKey:kGlobal];
    
    id value = [prefs objectForKey:kBackgroundingMethod];
    if ([value isKindOfClass:[NSNumber class]])
        backgroundingMethod = [value integerValue];
}

//==============================================================================

// Callback
static void toggleBackgrounding(int signal)
{
    if (backgroundingMethod == 2)
        backgroundingEnabled = !backgroundingEnabled;
}

//==============================================================================

// NOTE: This struct comes from UIApplication; note that this declaration is incomplete.
//       These first few members are valid in firmwares 3.0 - 3.2.
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
} UIApplicationFlags;

%group GApplication

%hook UIApplication

// Delegate method
// NOTE: Only hooked when backgroundingMethod == 2
- (void)applicationWillResignActive:(id)application
{
    if (!backgroundingEnabled)
        %orig;
}

// Delegate method
// NOTE: Only hooked when backgroundingMethod == 2
- (void)applicationDidBecomeActive:(id)application
{
    if (!backgroundingEnabled)
        %orig;
}

// Prevent execution of application's on-suspend method
// NOTE: Normally this method does nothing; only system apps can overrride
// NOTE: Only hooked when backgroundingMethod == 2
- (void)applicationWillSuspend
{
    if (!backgroundingEnabled)
        %orig;
}

// Prevent execution of application's on-resume methods
// NOTE: Normally this method does nothing; only system apps can overrride
// NOTE: Only hooked when backgroundingMethod == 2
- (void)applicationDidResume
{
    if (!backgroundingEnabled)
        %orig;
}

// Overriding this method prevents the application from quitting on suspend
// NOTE: UIApplication's default implementation of applicationSuspend: simply
//       sets _applicationFlags.shouldExitAfterSendSuspend to YES
- (void)applicationSuspend:(GSEventRef)event
{
    // NOTE: backgroundingEnabled will always be NO for backgroundingMethod == 0
    if (!backgroundingEnabled) {
        %orig;

        // Application should terminate on suspend; make certain that it does
        // FIXME: Determine if there is any benefit of using shouldExitAfterSendSuspend
        //        over forceExit.
        UIApplicationFlags &_applicationFlags = MSHookIvar<UIApplicationFlags>(self, "_applicationFlags");
        _applicationFlags.shouldExitAfterSendSuspend = YES;
    }
}

// Used by certain applications, such as Mail and Phone, instead of applicationSuspend:
// NOTE: Only hooked when backgroundingMethod == 0
- (void)applicationSuspend:(GSEventRef)event settings:(id)settings
{
    // NOTE: backgroundingEnabled will always be NO for backgroundingMethod == 0
    if (!backgroundingEnabled) {
        %orig;

        // Application should terminate on suspend; make certain that it does
        // NOTE: The shouldExitAfterSendSuspend flag appears to be ignored when
        //       this alternative method is called; resort to more "drastic"
        //       measures.
        UIApplicationFlags &_applicationFlags = MSHookIvar<UIApplicationFlags>(self, "_applicationFlags");
        _applicationFlags.forceExit = YES;
    }
}

%end

%end // GApplication

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

    if (backgroundingMethod == 1)
        // Backgrounding method is set to native; do not hook anything else
        return;

    // NOTE: Application class may be a subclass of UIApplication (and not UIApplication itself)
    Class $$UIApplication = [self class];
    MSHookMessage($$UIApplication, @selector(applicationSuspend:), MSHake(GApplication$UIApplication$applicationSuspend$));
    if (class_getInstanceMethod($$UIApplication, @selector(applicationSuspend:settings:)) != NULL)
            MSHookMessage($$UIApplication, @selector(applicationSuspend:settings:),
                    MSHake(GApplication$UIApplication$applicationSuspend$settings$));

    if (backgroundingMethod == 2) {
        MSHookMessage($$UIApplication, @selector(applicationWillSuspend), MSHake(GApplication$UIApplication$applicationWillSuspend));
        MSHookMessage($$UIApplication, @selector(applicationDidResume), MSHake(GApplication$UIApplication$applicationDidResume));

        id delegate = [self delegate];
        Class $AppDelegate = delegate ? [delegate class] : [self class];
        if (class_getInstanceMethod($AppDelegate, @selector(applicationWillResignActive:)) != NULL)
            MSHookMessage($AppDelegate, @selector(applicationWillResignActive:),
                    MSHake(GApplication$UIApplication$applicationWillResignActive$));
        if (class_getInstanceMethod($AppDelegate, @selector(applicationDidBecomeActive:)) != NULL)
            MSHookMessage($AppDelegate, @selector(applicationDidBecomeActive:),
                    MSHake(GApplication$UIApplication$applicationDidBecomeActive$));
    }

    if (NO)
        // FIXME: This is needed to prevent Logos from complaining about an unused
        //        hook group.
        %init(GApplication);
}

%new(c@:)
- (BOOL)isBackgroundingEnabled
{
    return backgroundingEnabled;
}

%new(v@:c)
- (void)setBackgroundingEnabled:(BOOL)enable
{
    if (backgroundingMethod == 2)
        backgroundingEnabled = enable;
}

%end

//==============================================================================

void initApplicationHooks()
{
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
