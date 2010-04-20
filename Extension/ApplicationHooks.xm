/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-04-21 00:01:45
 */

/**
 * Copyright (C) 2008-2009  Lance Fetters (aka. ashikase)
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
static BOOL isBlacklisted = NO;

#define GSEventRef void *

//==============================================================================

static void loadPreferences()
{
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("blacklistedApplications"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFArrayGetTypeID())
            isBlacklisted = [(NSArray *)propList containsObject:[[NSBundle mainBundle] bundleIdentifier]];
        CFRelease(propList);
    }
}

//==============================================================================

// Callback
static void toggleBackgrounding(int signal)
{
    backgroundingEnabled = !backgroundingEnabled;
}

//==============================================================================

%group GApplication

%hook UIApplication

// Prevent execution of application's on-suspend method
// NOTE: Normally this method does nothing; only system apps can overrride
- (void)applicationWillSuspend
{
#if 0
    [self removeStatusBarImageNamed:
        [NSString stringWithFormat:@"Backgrounder"]];
#endif

    if (!backgroundingEnabled)
        %orig;
}

// Prevent execution of application's on-resume methods
// NOTE: Normally this method does nothing; only system apps can overrride
- (void)applicationDidResume
{
#if 0
    NSString *name = [NSString stringWithFormat:@"Backgrounder"];
    if ([self respondsToSelector:@selector(addStatusBarImageNamed:removeOnExit:)])
        [self addStatusBarImageNamed:name removeOnExit:YES];
    else
        [self addStatusBarImageNamed:name removeOnAbnormalExit:YES];
#endif

    if (!backgroundingEnabled)
        %orig;
}

// Overriding this method prevents the application from quitting on suspend
- (void)applicationSuspend:(GSEventRef)event
{
    if (!backgroundingEnabled)
        %orig;
}

- (void)applicationWillResignActive:(id)application
{
    if (!backgroundingEnabled)
        %orig;
}

- (void)applicationDidBecomeActive:(id)application
{
    if (!backgroundingEnabled)
        %orig;
}

%end

%end // GApplication

//==============================================================================

%hook UIApplication

// Prevent execution of application's on-suspend method
// NOTE: Normally this method does nothing; only system apps can overrride
- (void)applicationWillSuspend
{
#if 0
    [self removeStatusBarImageNamed:
        [NSString stringWithFormat:@"Backgrounder"]];
#endif

    if (!backgroundingEnabled)
        %orig;
}

// Prevent execution of application's on-resume methods
// NOTE: Normally this method does nothing; only system apps can overrride
- (void)applicationDidResume
{
#if 0
    NSString *name = [NSString stringWithFormat:@"Backgrounder"];
    if ([self respondsToSelector:@selector(addStatusBarImageNamed:removeOnExit:)])
        [self addStatusBarImageNamed:name removeOnExit:YES];
    else
        [self addStatusBarImageNamed:name removeOnAbnormalExit:YES];
#endif

    if (!backgroundingEnabled)
        %orig;
}

// Overriding this method prevents the application from quitting on suspend
- (void)applicationSuspend:(GSEventRef)event
{
    if (!backgroundingEnabled)
        %orig;
}

- (void)_loadMainNibFile
{
    // NOTE: This method always gets called, even if no NIB files are used.
    //       This method was chosen as it is called after the application
    //       delegate has been set.
    // NOTE: If an application overrides this method (unlikely, but possible),
    //       this extension's hooks will not be installed.
    %orig;

    // NOTE: May be a subclass of UIApplication
    Class $$UIApplication = [self class];
    MSHookMessage($$UIApplication, @selector(applicationSuspend:), MSHake(GApplication$UIApplication$applicationSuspend$));
    MSHookMessage($$UIApplication, @selector(applicationWillSuspend), MSHake(GApplication$UIApplication$applicationWillSuspend));
    MSHookMessage($$UIApplication, @selector(applicationDidResume), MSHake(GApplication$UIApplication$applicationDidResume));
    if (NO)
        %init(GApplication);

    id delegate = [self delegate];
    Class $AppDelegate = delegate ? [delegate class] : [self class];
    if (class_getInstanceMethod($AppDelegate, @selector(applicationWillResignActive:)) != NULL)
        MSHookMessage($AppDelegate, @selector(applicationWillResignActive:),
                MSHake(GApplication$UIApplication$applicationWillResignActive$));
    if (class_getInstanceMethod($AppDelegate, @selector(applicationDidBecomeActive:)) != NULL)
        MSHookMessage($AppDelegate, @selector(applicationDidBecomeActive:),
                MSHake(GApplication$UIApplication$applicationDidBecomeActive$));
}

%new(c@:)
- (BOOL)isBackgroundingEnabled
{
    return backgroundingEnabled;
}

%new(v@:c)
- (void)setBackgroundingEnabled:(BOOL)enable
{
    backgroundingEnabled = enable;
}

%end

//==============================================================================

void initApplicationHooks()
{
    loadPreferences();

    if (!isBlacklisted)
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

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
