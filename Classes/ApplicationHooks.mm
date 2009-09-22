/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-09-10 21:10:09
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


#import <CoreFoundation/CoreFoundation.h>

struct GSEvent;


static BOOL backgroundingEnabled = NO;
static BOOL isBlacklisted = NO;
static BOOL animationsEnabled = NO;

//______________________________________________________________________________
//______________________________________________________________________________

static void loadPreferences()
{
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("blacklistedApplications"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFArrayGetTypeID())
            isBlacklisted = [(NSArray *)propList containsObject:[[NSBundle mainBundle] bundleIdentifier]];
        CFRelease(propList);
    }

#if 0
    propList = CFPreferencesCopyAppValue(CFSTR("animationsEnabled"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            animationsEnabled = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }
#endif
}

//______________________________________________________________________________
//______________________________________________________________________________

// Callback
static void toggleBackgrounding(int signal)
{
    backgroundingEnabled = !backgroundingEnabled;
}

// Class methods
static BOOL $UIApplication$isBackgroundingEnabled(id self, SEL sel)
{
    return backgroundingEnabled;
}

static void $UIApplication$setBackgroundingEnabled$(id self, SEL sel, BOOL enable)
{
    backgroundingEnabled = enable;
}

//______________________________________________________________________________
//______________________________________________________________________________

// NOTE: Only hooked when animationsEnabled = YES
HOOK(UIApplication, nameOfDefaultImageToUpdateAtSuspension, NSString *)
{
    // FIXME: Find a better solution for the Categories "transparent-window" issue
    NSString *path = CALL_ORIG(UIApplication, nameOfDefaultImageToUpdateAtSuspension);
    return (path || [[self displayIdentifier] hasPrefix:@"com.bigboss.categories."]) ? path : @"Default";
}

// Prevent execution of application's on-suspend/resume methods
HOOK(UIApplication, applicationWillSuspend, void)
{
#if 0
    [self removeStatusBarImageNamed:
        [NSString stringWithFormat:@"Backgrounder"]];
#endif

    if (!backgroundingEnabled)
        CALL_ORIG(UIApplication, applicationWillSuspend);
}

HOOK(UIApplication, applicationDidResume, void)
{
#if 0
    NSString *name = [NSString stringWithFormat:@"Backgrounder"];
    if ([self respondsToSelector:@selector(addStatusBarImageNamed:removeOnExit:)])
        [self addStatusBarImageNamed:name removeOnExit:YES];
    else
        [self addStatusBarImageNamed:name removeOnAbnormalExit:YES];
#endif

    if (!backgroundingEnabled)
        CALL_ORIG(UIApplication, applicationDidResume);
}

HOOK(UIApplication, applicationWillResignActive$, void, id application)
{
    if (!backgroundingEnabled)
        CALL_ORIG(UIApplication, applicationWillResignActive$, application);
}

HOOK(UIApplication, applicationDidBecomeActive$, void, id application)
{
    if (!backgroundingEnabled)
        CALL_ORIG(UIApplication, applicationDidBecomeActive$, application);
}

// NOTE: Only hooked when animationsEnabled = YES
HOOK(UIApplication, applicationWillTerminate$, void, id application)
{
    if (CALL_ORIG(UIApplication, nameOfDefaultImageToUpdateAtSuspension) == nil)
        // App does not normally produce a default image; safe to delete
        [application removeDefaultImage:@"Default"];

    CALL_ORIG(UIApplication, applicationWillTerminate$, application);
}

// Overriding this method prevents the application from quitting on suspend
HOOK(UIApplication, applicationSuspend$, void, GSEvent *event)
{
    if (!backgroundingEnabled)
        CALL_ORIG(UIApplication, applicationSuspend$, event);
}

// FIXME: Tests make this appear unneeded... confirm
#if 0
static void $UIApplication$_setSuspended$(UIApplication *self, SEL sel, BOOL val)
{
    //[self bg__setSuspended:val];
}
#endif

HOOK(UIApplication, _loadMainNibFile, void)
{
    // NOTE: This method always gets called, even if no NIB files are used.
    //       Also note that if an application overrides this method (unlikely,
    //       but possible), this extension's hooks will not be installed.
    CALL_ORIG(UIApplication, _loadMainNibFile);

    if (!isBlacklisted) {
        Class $UIApplication([self class]);
        _UIApplication$applicationSuspend$ =
            MSHookMessage($UIApplication, @selector(applicationSuspend:), &$UIApplication$applicationSuspend$);
        _UIApplication$applicationWillSuspend =
            MSHookMessage($UIApplication, @selector(applicationWillSuspend), &$UIApplication$applicationWillSuspend);
        _UIApplication$applicationDidResume =
            MSHookMessage($UIApplication, @selector(applicationDidResume), &$UIApplication$applicationDidResume);

        id delegate = [self delegate];
        Class $AppDelegate(delegate ? [delegate class] : [self class]);
        _UIApplication$applicationWillResignActive$ =
            MSHookMessage($AppDelegate, @selector(applicationWillResignActive:), &$UIApplication$applicationWillResignActive$);
        _UIApplication$applicationDidBecomeActive$ =
            MSHookMessage($AppDelegate, @selector(applicationDidBecomeActive:), &$UIApplication$applicationDidBecomeActive$);
    }

    if (animationsEnabled) {
        Class $UIApplication([self class]);
        _UIApplication$nameOfDefaultImageToUpdateAtSuspension =
            MSHookMessage($UIApplication, @selector(nameOfDefaultImageToUpdateAtSuspension),
                &$UIApplication$nameOfDefaultImageToUpdateAtSuspension);

        id delegate = [self delegate];
        Class $AppDelegate(delegate ? [delegate class] : [self class]);
        _UIApplication$applicationWillTerminate$ =
            MSHookMessage($AppDelegate, @selector(applicationWillTerminate:), &$UIApplication$applicationWillTerminate$);

        // Make sure that "default images" directory exists
        NSString *path = [NSString stringWithFormat:@"%@/%@", [self userLibraryDirectory], @"Caches/Snapshots"];
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

void initApplicationHooks()
{
    loadPreferences();

    Class $UIApplication(objc_getClass("UIApplication"));
    _UIApplication$_loadMainNibFile =
        MSHookMessage($UIApplication, @selector(_loadMainNibFile), &$UIApplication$_loadMainNibFile);

    if (!isBlacklisted) {
        class_addMethod($UIApplication, @selector(isBackgroundingEnabled), (IMP)&$UIApplication$isBackgroundingEnabled, "c@:");
        class_addMethod($UIApplication, @selector(setBackgroundingEnabled:), (IMP)&$UIApplication$setBackgroundingEnabled$, "v@:c");
    }

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
