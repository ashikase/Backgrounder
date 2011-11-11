/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-12-30 20:13:26
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

#import <substrate.h>

#import "Headers.h"

#define GSEventRef void *


static BOOL isFirmware3x_ = NO;
static BOOL isFirmware5x_ = NO;

static BOOL backgroundingEnabled_ = NO;
static BGBackgroundingMethod backgroundingMethod_ = BGBackgroundingMethodBackgrounder;
static BOOL fallbackToNative_ = YES;
static BOOL fastAppSwitchingEnabled_ = YES;
static BOOL forceFastAppSwitching_ = NO;

//==============================================================================

static void loadPreferences()
{
    NSString *displayId = [[UIApplication sharedApplication] displayIdentifier];

    // NOTE: System preferences are not accessible from App Store apps.
    //       A symlink to the preferences file is stored in /var/mobile,
    //       which *can* be accessed.
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:
        @"/var/mobile/Library/Preferences/jp.ashikase.backgrounder.plist"];

    NSDictionary *prefs = [[defaults objectForKey:kOverrides] objectForKey:displayId];
    if (prefs == nil)
        prefs = [defaults objectForKey:kGlobal];
    
    // Backgrounding method
    id value = [prefs objectForKey:kBackgroundingMethod];
    if ([value isKindOfClass:[NSNumber class]]) {
        backgroundingMethod_ = (BGBackgroundingMethod)[value integerValue];
        if (isFirmware3x_ && backgroundingMethod_ == BGBackgroundingMethodAutoDetect)
            backgroundingMethod_ = BGBackgroundingMethodBackgrounder;
    }

    // Fall Back to native
    // NOTE: This option is only available with "Backgrounder" method
    if (backgroundingMethod_ == BGBackgroundingMethodBackgrounder) {
        value = [prefs objectForKey:kFallbackToNative];
        if ([value isKindOfClass:[NSNumber class]])
            fallbackToNative_ = [value boolValue];
    } else {
        // Not "Backgrounder" method (the default); disable fall back
        fallbackToNative_ = NO;
    }

    // NOTE: These options are only available with "Native" method or "Fall Back"
    if (backgroundingMethod_ == BGBackgroundingMethodNative || fallbackToNative_) {
        // Fast app switching
        value = [prefs objectForKey:kFastAppSwitchingEnabled];
        if ([value isKindOfClass:[NSNumber class]])
            fastAppSwitchingEnabled_ = [value boolValue];

        // Enable fast app switching for apps not yet updated for iOS 4
        value = [prefs objectForKey:kForceFastAppSwitching];
        if ([value isKindOfClass:[NSNumber class]])
            forceFastAppSwitching_ = [value boolValue];
    }
}

//------------------------------------------------------------------------------

// NOTE: This function is based on work by Jay Freeman (a.k.a. saurik)
template <typename Type_>
static inline void lookupSymbol(const char *libraryFilePath, const char *symbolName, Type_ &symbol)
{
    // Lookup the symbol
    struct nlist nl[2];
    memset(nl, 0, sizeof(nl));
    nl[0].n_un.n_name = (char *)symbolName;
    nlist(libraryFilePath, nl);

    // Check whether it is ARM or Thumb
    uintptr_t value = nl[0].n_value;
    if ((nl[0].n_desc & N_ARM_THUMB_DEF) != 0)
        value |= 0x00000001;

    symbol = reinterpret_cast<Type_>(value);
}

//------------------------------------------------------------------------------

static inline NSMutableArray *backgroundTasks()
{
    NSMutableArray **_backgroundTasks = NULL;
    lookupSymbol("/System/Library/Frameworks/UIKit.framework/UIKit", "__backgroundTasks", _backgroundTasks);

    return (_backgroundTasks != NULL) ? *_backgroundTasks : nil;
}

//==============================================================================

// NOTE: Hooked for all backgrounding methods

%group GMethodAll

%hook UIApplication

// NOTE: UIApplication's default implementation of applicationSuspend: simply
//       sets _applicationFlags.shouldExitAfterSendSuspend to YES
// FIXME: Currently, if Backgrounder method is in use and backgrounding is
//        enabled, applicationSuspend will not get called (it suspends "events only").
//        This is a side effect of a bug fix in SpringBoardHooks.xm.
- (void)applicationSuspend:(GSEventRef)event
{
    if (!isFirmware3x_) {
        // Firmware 4.x+

        if (backgroundingEnabled_ || fallbackToNative_) {
            // Is Native method
            // NOTE: backgroundingEnabled_ will always be NO here for
            //       "Off" and "Backgrounder" methods.

            // Check if fast app switching is disabled for this app
            if (!fastAppSwitchingEnabled_ && [[self _backgroundModes] count] == 0) {
                // Fast app switching is disabled, and app does not support audio/gps/voip
                if ([backgroundTasks() count] == 0) {
                    // No outstanding background tasks; safe to terminate
                    UIApplicationFlags4x &_applicationFlags4x = MSHookIvar<UIApplicationFlags4x>(self, "_applicationFlags");
                    UIApplicationFlags5x &_applicationFlags5x = MSHookIvar<UIApplicationFlags5x>(self, "_applicationFlags");
                    if (isFirmware5x_)
                        _applicationFlags5x.taskSuspendingUnsupported = 1;
                    else
                        _applicationFlags4x.taskSuspendingUnsupported = 1;
                }
            }
        } else {
            // If there are any outstanding background tasks, terminate them
            for (id task in backgroundTasks()) {
                unsigned int taskId = MSHookIvar<unsigned int>(task, "_taskId");
                [self endBackgroundTask:taskId];
            }

            // Application should terminate on suspend; make certain that it does
            // NOTE: If there were any remaining tasks, the app will terminate
            //       before this code is reached.
            UIApplicationFlags4x &_applicationFlags4x = MSHookIvar<UIApplicationFlags4x>(self, "_applicationFlags");
            UIApplicationFlags5x &_applicationFlags5x = MSHookIvar<UIApplicationFlags5x>(self, "_applicationFlags");
            if (isFirmware5x_)
                _applicationFlags5x.taskSuspendingUnsupported = 1;
            else
                _applicationFlags4x.taskSuspendingUnsupported = 1;
        }

        // Call original implementation
        %orig;
    } else {
        // Firmware 3.x

        // Call original implementation
        %orig;

        if (!backgroundingEnabled_ && !fallbackToNative_) {
            // Application should terminate on suspend; make certain that it does
            // FIXME: Determine if there is any benefit of using shouldExitAfterSendSuspend
            //        over forceExit.
            UIApplicationFlags3x &_applicationFlags = MSHookIvar<UIApplicationFlags3x>(self, "_applicationFlags");
            _applicationFlags.shouldExitAfterSendSuspend = YES;
        }
    }
}

%end

%end // GMethodAll

//------------------------------------------------------------------------------

%group GMethodAll_SuspendSettings

%hook UIApplication

// not iOS 5
// Used by certain system applications, such as Mail and Phone, instead of applicationSuspend:
- (BOOL)applicationSuspend:(GSEventRef)event settings:(id)settings
{
    // NOTE: The return value for this method appears to not be used;
    //       perhaps a leftover from 1.x/2.x?
    // FIXME: Confirm this.
    BOOL ret = NO;

    if (!backgroundingEnabled_ || backgroundingMethod_ != BGBackgroundingMethodBackgrounder) {
        ret = %orig;

        if (!backgroundingEnabled_ && !fallbackToNative_) {
            // Application should terminate on suspend; make certain that it does
            if (isFirmware3x_) {
                // NOTE: The shouldExitAfterSendSuspend flag appears to be ignored when
                //       this alternative method is called; resort to more "drastic"
                //       measures.
                UIApplicationFlags3x &_applicationFlags = MSHookIvar<UIApplicationFlags3x>(self, "_applicationFlags");
                _applicationFlags.forceExit = YES;
            } else {
                // FIXME: Not certain if this is the best method for forcing termination.
                // commented by deVbug
                //[self terminateWithSuccess];
            }
        }
    }

    return ret;
}

%end

%end // GMethodAll_SuspendSettings

//==============================================================================

// NOTE: Only hooked for BGBackgroundingMethodOff on firmware 4.x+

%group GMethodOff

%hook UIDevice

- (BOOL)isMultitaskingSupported
{
    // NOTE: This is for apps that properly check for multitasking support
    return NO;
}

%end

%end // GMethodOff

//==============================================================================

// NOTE: Only hooked for BGBackgroundingMethodBackgrounder

%group GMethodBackgrounder

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

extern "C" NSString *const UIApplicationDidBecomeActiveNotification;
extern "C" NSString *const UIApplicationWillResignActiveNotification;

%hook NSNotificationCenter

- (void)postNotificationName:(NSString *)notificationName object:(id)notificationSender userInfo:(NSDictionary *)userInfo
{
    if (backgroundingEnabled_) {
        // If backgrounding is enabled, must block these notifications.
        // NOTE: Some apps use these notifications instead of the related delgate methods.
        if ([notificationName isEqualToString:UIApplicationWillResignActiveNotification]
                || [notificationName isEqualToString:UIApplicationDidBecomeActiveNotification])
            return;
    }

    %orig;
}

%end

%end // GMethodBackgrounder

//------------------------------------------------------------------------------

%group GMethodBackgrounder_Resign

%hook AppDelegate

// Delegate method
- (void)applicationWillResignActive:(id)application
{
    if (!backgroundingEnabled_)
        %orig;
}

%end

%end // GMethodBackgrounder_Resign

//------------------------------------------------------------------------------

%group GMethodBackgrounder_Become

%hook AppDelegate

// Delegate method
- (void)applicationDidBecomeActive:(id)application
{
    if (!backgroundingEnabled_)
        %orig;
}

%end

%end // GMethodBackgrounder_Become

//==============================================================================

// NOTE: Only hooked if fast app switching is disabled for the app

%group GFastAppSwitchingOff

%hook UIApplication

// NOTE: UIApplication includes a flag, shouldExitAfterTaskCompletion, which is
//       used to determine whether or not the app should stay loaded in memory
//       after the last task completes. However, the app ends up suspending
//       *before* this flag is ever checked. If the flag is set, once the app
//       is brought to the foreground again, *then* it will terminate.
// FIXME: Determine if there is a reason for this design, or if this is a miss
//        on Apple's part.
- (void)endBackgroundTask:(unsigned int)backgroundTaskId
{
    // NOTE: Only terminate if app is suspended.
    UIApplicationFlags4x &_applicationFlags4x = MSHookIvar<UIApplicationFlags4x>(self, "_applicationFlags");
    UIApplicationFlags5x &_applicationFlags5x = MSHookIvar<UIApplicationFlags5x>(self, "_applicationFlags");
    
    BOOL isSuspended = isFirmware5x_ ? _applicationFlags5x.isSuspended : _applicationFlags4x.isSuspended;
    
    if (isSuspended) {
        // If this is the last task, terminate the app instead of suspending
        NSMutableArray *tasks = backgroundTasks();
        if ([tasks count] == 1) {
            // Only one task left; make sure the task ID matches
            id task = [tasks lastObject];
            unsigned int taskId = MSHookIvar<unsigned int>(task, "_taskId");
            if (taskId == backgroundTaskId)
                // The requested ID matches; terminate the app
                // NOTE: Terminating the app here will result in a
                //       "pid_suspend failed" message being printed to the syslog
                //       by SpringBoard. An examination of SpringBoard appears to
                //       show that this is harmless.
                // FIXME: Confirm that this is, indeed, harmless.
                [self terminateWithSuccess];
        }
    }

    // Not the last task or matching task not found
    %orig;
}

%end

%end // GFastAppSwitchingOff

//==============================================================================

// Callback
static void toggleBackgrounding(int signal)
{
    if (backgroundingMethod_ != BGBackgroundingMethodOff)
        backgroundingEnabled_ = !backgroundingEnabled_;
}

//------------------------------------------------------------------------------

@interface UIApplication (Backgrounder)
- (void)initBackgrounder;
@end


%hook UIApplication


%new(v:)
- (void)initBackgrounder
{
    // Load preferences to determine backgrounding method to use
    loadPreferences();
    
    if (!isFirmware3x_) {
        // Get application flags
        UIApplicationFlags4x &_applicationFlags4x = MSHookIvar<UIApplicationFlags4x>(self, "_applicationFlags");
        UIApplicationFlags5x &_applicationFlags5x = MSHookIvar<UIApplicationFlags5x>(self, "_applicationFlags");
        
        if (backgroundingMethod_ == BGBackgroundingMethodAutoDetect) {
            // Determine if native multitasking is supported
            // NOTE: taskSuspendingUnsupported is set either if the app was
            //       compiled with a pre-iOS4 version of UIKit, or if the info
            //       plist file has the UIApplicationExitsOnSuspend flag set.
            BOOL supportsMultitask = isFirmware5x_ ? !_applicationFlags5x.taskSuspendingUnsupported : !_applicationFlags4x.taskSuspendingUnsupported;
            
            // NOTE: App may have been built with 3.x SDK but still supports multitask;
            //       check if app supports any of the allowed background modes.
            //       (One known example is TomTom.)
            supportsMultitask |= ([[self _backgroundModes] count] != 0);
            
            // If multitasking is supported, use "Native" method; else use "Backgrounder"
            backgroundingMethod_ = supportsMultitask ? BGBackgroundingMethodNative : BGBackgroundingMethodBackgrounder;
        } else if (backgroundingMethod_ == BGBackgroundingMethodNative || fallbackToNative_) {
            if (fastAppSwitchingEnabled_) {
                // NOTE: Only need to modify flag if "force" option is set;
                //       apps updated for iOS4 will already have the flag set to zero.
                if (forceFastAppSwitching_) {
                    // Determine if native multitasking is purposely disabled
                    BOOL exitsOnSuspend = NO;
                    NSBundle *bundle = [NSBundle mainBundle];
                    id value = [bundle objectForInfoDictionaryKey:@"UIApplicationExitsOnSuspend"]; 
                    if ([value isKindOfClass:[NSNumber class]])
                        exitsOnSuspend = [(NSNumber *)value boolValue];
                        
                    // NOTE: Respect UIApplicationExitsOnSuspend flag
                    if (isFirmware5x_)
                        _applicationFlags5x.taskSuspendingUnsupported = NO;
                    else
                        _applicationFlags4x.taskSuspendingUnsupported = NO;
                }
            } else {
                if ([[self _backgroundModes] count] == 0) {
                    // App does not support audio/gps/voip; disable fast app switching
                    
                    // Setup hooks to handle task-continuation
                    %init(GFastAppSwitchingOff);
                }
            }
        }
        
        if (backgroundingMethod_ == BGBackgroundingMethodOff
            || (backgroundingMethod_ == BGBackgroundingMethodBackgrounder && !fallbackToNative_)) {
            // Disable native backgrounding
            // NOTE: Must hook for Backgrounder method as well to prevent task-continuation
            if (isFirmware5x_)
                _applicationFlags5x.taskSuspendingUnsupported = 1;
            else
                _applicationFlags4x.taskSuspendingUnsupported = 1;
            
            %init(GMethodOff);
        }
    }
    
    // NOTE: Application class may be a subclass of UIApplication (and not UIApplication itself)
    Class $UIApplication = [self class];
    if (!isFirmware5x_) {
        %init(GMethodAll, UIApplication = $UIApplication);
        if ([self respondsToSelector:@selector(applicationSuspend:settings:)])
            %init(GMethodAll_SuspendSettings, UIApplication = $UIApplication);
    }
        
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


%group UnderiOS4

- (void)_loadMainNibFile
{
    // NOTE: This method always gets called, even if no NIB files are used.
    //       This method was chosen as it is called after the application
    //       delegate has been set.
    // NOTE: If an application overrides this method (unlikely, but possible),
    //       this extension's hooks will not be installed.
    %orig;

    [self initBackgrounder];
}

%end


%group iOS5

- (void)_loadMainInterfaceFile
{
    %orig;
    
    [self initBackgrounder];
}

%end

%end

//==============================================================================

void initApplicationHooks()
{
    Class $UIApplication = objc_getClass("UIApplication");
    isFirmware3x_ = (class_getInstanceMethod($UIApplication, @selector(applicationState)) == NULL);
    isFirmware5x_ = (class_getInstanceMethod($UIApplication, @selector(_loadMainNibFile)) == NULL);
    
    %init;

    if (isFirmware5x_)
        %init(iOS5);
    else
        %init(UnderiOS4);
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
