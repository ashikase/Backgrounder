/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-04-03 23:49:36
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


#import "SpringBoardHooks.h"

#import <CoreFoundation/CoreFoundation.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SpringBoard.h>

#import <substrate.h>

#import "BackgrounderActivator.h"
#import "SimplePopup.h"

@interface UIModalView : UIView
@property(nonatomic,copy) NSString *title;
@end

struct GSEvent;


static BOOL isPersistent = YES;

static NSMutableArray *activeApps = nil;
static NSMutableArray *bgEnabledApps = nil;
static NSArray *blacklistedApps = nil;

#if 0
static NSMutableDictionary *statusBarStates = nil;
static NSString *deactivatingApp = nil;

static BOOL animateStatusBar = YES;
#endif

static BOOL badgeEnabled = NO;
static BOOL badgeEnabledForAll = YES;

//==============================================================================

static void loadPreferences()
{
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("persistent"), CFSTR(APP_ID));
    if (propList) {
        // NOTE: Defaults to YES
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            isPersistent = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("badgeEnabled"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            badgeEnabled = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("badgeEnabledForAll"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            badgeEnabledForAll = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("blacklistedApplications"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFArrayGetTypeID())
            blacklistedApps = [[NSArray alloc] initWithArray:(NSArray *)propList];
        CFRelease(propList);
    }

    // Invocation type
    // NOTE: This setting is from pre-libactivator; convert and remove
    propList = CFPreferencesCopyAppValue(CFSTR("invocationMethod"), CFSTR(APP_ID));
    if (propList) {
        NSString *eventName = nil;
        if ([(NSString *)propList isEqualToString:@"homeShortHold"])
            eventName = LAEventNameMenuHoldShort;
        else if ([(NSString *)propList isEqualToString:@"powerShortHold"])
            eventName = LAEventNameLockHoldShort;
        CFRelease(propList);

        // Register the event type with libactivator
        [[LAActivator sharedInstance] assignEvent:[LAEvent eventWithName:eventName] toListenerWithName:@APP_ID];

        // Remove the preference, as it is no longer used
        CFPreferencesSetAppValue(CFSTR("invocationMethod"), NULL, CFSTR(APP_ID));
        CFPreferencesAppSynchronize(CFSTR(APP_ID));
    }
}

//==============================================================================

@interface UIView (Private)
- (void)setOrigin:(CGPoint)origin;
@end

static void showBadgeForDisplayIdentifier(NSString *identifier)
{
    // Update the application's SpringBoard icon to indicate that it is running
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
    if (![icon viewWithTag:1000]) {
        // Icon does not have a badge
        UIImageView *badgeView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Backgrounder_Badge.png"]];
        [badgeView setOrigin:CGPointMake(-12.0f, 39.0f)];
        [badgeView setTag:1000];
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

#if 0
HOOK(SBStatusBarController, setStatusBarMode$mode$orientation$duration$fenceID$animation$,
    void, int mode, int orientation, float duration, int fenceID, int animation)
{
    if (!animateStatusBar) {
        duration = 0;
        // Reset the flag to default (animation enabled)
        animateStatusBar = YES;
    }
    CALL_ORIG(SBStatusBarController, setStatusBarMode$mode$orientation$duration$fenceID$animation$,
            mode, orientation, duration, fenceID, animation);
}
#endif

//==============================================================================

// The alert window displays instructions when the home button is held down
static BackgrounderAlertItem *alert = nil;

//==============================================================================

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    // NOTE: SpringBoard creates four stacks at startup
    displayStacks = [[NSMutableArray alloc] initWithCapacity:4];

    // NOTE: The initial capacity value was chosen to hold the default active
    //       apps (MobilePhone and MobileMail) plus two others
    activeApps = [[NSMutableArray alloc] initWithCapacity:4];
    bgEnabledApps = [[NSMutableArray alloc] initWithCapacity:2];

#if 0
    // Create a dictionary to store the statusbar state for active apps
    // FIXME: Determine a way to do this without requiring extra storage
    statusBarStates = [[NSMutableDictionary alloc] initWithCapacity:5];
#endif

    // Initialize simple notification popup
    initSimplePopup();

    %orig;
}

- (void)dealloc
{
    [bgEnabledApps release];
    [activeApps release];
    [displayStacks release];
    %orig;
}

- (void)_handleMenuButtonEvent
{
    // Remove the popup (may not be present)
    [self dismissBackgrounderFeedback];

    %orig;
}

- (void)lockButtonUp:(GSEventRef)event
{
    if (alert != nil) {
        // Backgrounder was invoked

        // Reset the lock button state
        [self _unsetLockButtonBearTrap];
        [self _setLockButtonTimer:nil];

        // Simulate home-button press to dismiss feedback and suspend application
        [self performSelector:@selector(simulateMenuButtonTap) withObject:nil];
    } else {
        %orig;
    }
}

%new(v@:)
- (void)invokeBackgrounder
{
    [self invokeBackgrounderAndAutoDismiss:YES];
}

%new(v@:)
- (void)invokeBackgrounderAndAutoDismiss:(BOOL)autoDismiss
{
    id app = [SBWActiveDisplayStack topApplication];
    NSString *identifier = [app displayIdentifier];
    if (app && ![blacklistedApps containsObject:identifier]) {
        BOOL isEnabled = [bgEnabledApps containsObject:identifier];
        [self setBackgroundingEnabled:(!isEnabled) forDisplayIdentifier:identifier];

        // Display simple popup
        NSString *status = [NSString stringWithFormat:@"Backgrounding %s",
                 (isEnabled ? "Disabled" : "Enabled")];

        alert = [[objc_getClass("BackgrounderAlertItem") alloc] initWithTitle:status message:nil];

        SBAlertItemsController *controller = [objc_getClass("SBAlertItemsController") sharedInstance];
        [controller activateAlertItem:alert];

        if (autoDismiss)
            // After delay, simulate menu button tap to suspend current app
            [self performSelector:@selector(simulateMenuButtonTap) withObject:nil afterDelay:0.6f];
    }
}

%new(v@:)
- (void)simulateMenuButtonTap
{
    [self menuButtonDown:nil];
    [self menuButtonUp:nil];
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
- (void)cancelPreviousBackgrounderRequest
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

        // Dismiss feedback after short delay (else cancellation message will not be seen)
        [self performSelector:@selector(dismissBackgrounderFeedback) withObject:nil afterDelay:1.0f];
    }
}

%new(v@:c@)
- (void)setBackgroundingEnabled:(BOOL)enable forDisplayIdentifier:(NSString *)identifier
{
    if (![blacklistedApps containsObject:identifier]) {
        // Not blacklisted
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

%end

//==============================================================================

%hook SBApplication

- (void)launchSucceeded:(BOOL)unknownFlag
{
    NSString *identifier = [self displayIdentifier];

    BOOL isAlwaysEnabled = NO;
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("enabledApplications"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFArrayGetTypeID())
            isAlwaysEnabled = [(NSArray *)propList containsObject:identifier];
        CFRelease(propList);
    }

    if ([activeApps containsObject:identifier]) {
        // Was restored from backgrounded state
        if (!isPersistent && !isAlwaysEnabled) {
            // Tell the application to disable backgrounding
            kill([self pid], SIGUSR1);

            // Store the backgrounding status of the application
            [bgEnabledApps removeObject:identifier];
        } 
    } else {
        // Initial launch; check if this application is set to always background
        if (isAlwaysEnabled) {
            // Tell the application to enable backgrounding
            kill([self pid], SIGUSR1);

            // Store the backgrounding status of the application
            [bgEnabledApps addObject:identifier];
        }

        // Track active status of application
        [activeApps addObject:identifier];
    }

    if (badgeEnabled && (badgeEnabledForAll || [bgEnabledApps containsObject:identifier]))
        // NOTE: This is mainly to catch applications that start in the background
        showBadgeForDisplayIdentifier(identifier);

    %orig;
}

- (void)exitedAbnormally
{
    [bgEnabledApps removeObject:[self displayIdentifier]];
    %orig;
}

- (void)exitedCommon
{
    // Application has exited (either normally or abnormally);
    // remove from active applications list
    NSString *identifier = [self displayIdentifier];
    [activeApps removeObject:identifier];

#if 0
    // ... also remove status bar state data from states list
    [statusBarStates removeObjectForKey:identifier];
#endif

    if (badgeEnabled) {
        // Update the SpringBoard icon to indicate that the app is not running
        SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
        [[icon viewWithTag:1000] removeFromSuperview];
    }

    %orig;
}

- (void)deactivate
{
#if 0
    NSString *identifier = [self displayIdentifier];
    if ([identifier isEqualToString:deactivatingApp]) {
        [[objc_getClass("SpringBoard") sharedApplication] dismissBackgrounderFeedback];
        [deactivatingApp release];
        deactivatingApp = nil;
    }

    // Store the status bar state of the current application
    SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
    NSNumber *mode = [NSNumber numberWithInt:[sbCont statusBarMode]];
    NSNumber *orientation = [NSNumber numberWithInt:[sbCont statusBarOrientation]];
    [statusBarStates setObject:[NSArray arrayWithObjects:mode, orientation, nil] forKey:identifier];
#endif

    NSString *identifier = [self displayIdentifier];
    BOOL isBackgrounded = [bgEnabledApps containsObject:identifier];

    if (badgeEnabled && (badgeEnabledForAll || isBackgrounded))
        // In case badge has not been added yet, add now
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

%hook SBVoiceControlAlert

+ (BOOL)shouldEnterVoiceControl
{
    BOOL flag = %orig;
    if (flag) {
        // Voice Control will appear
        if (alert != nil) {
            // Backgrounder was invoked, cancel request
            SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
            [springBoard cancelPreviousBackgrounderRequest];
        }
    }
    return flag;
}

%end

//==============================================================================

void initSpringBoardHooks()
{
    loadPreferences();

    // Create the libactivator event listener
    // NOTE: must load this *after* loading preferences, or else default
    //       invocation method may mistakenly be set when another pre-Activator
    //       method is already enabled.
    [BackgrounderActivator load];

#if 0
    Class $SBStatusBarController(objc_getClass("SBStatusBarController"));
    LOAD_HOOK($SBStatusBarController, @selector(setStatusBarMode:orientation:duration:fenceID:animation:),
        SBStatusBarController$setStatusBarMode$mode$orientation$duration$fenceID$animation$);
#endif

    %init;

#if 0
    LOAD_HOOK($SBApplication, @selector(_relaunchAfterAbnormalExit:), SBApplication$_relaunchAfterAbnormalExit$);
    LOAD_HOOK($SBApplication, @selector(pathForDefaultImage:), SBApplication$pathForDefaultImage$);
#endif
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
