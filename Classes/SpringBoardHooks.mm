/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-08-26 00:51:29
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
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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

#import "Common.h"
#import "SimplePopup.h"
#import "TaskMenuPopup.h"

struct GSEvent;


static BOOL isPersistent = YES;

#define SIMPLE_POPUP 0
#define TASK_MENU_POPUP 1
static int feedbackType = SIMPLE_POPUP;

#define HOME_SHORT_PRESS 0
#define HOME_DOUBLE_TAP 1
static int invocationMethod = HOME_SHORT_PRESS;

static NSMutableArray *activeApps = nil;
static NSMutableArray *bgEnabledApps = nil;
static NSArray *blacklistedApps = nil;

#if 0
static NSMutableDictionary *statusBarStates = nil;
static NSString *deactivatingApp = nil;

static NSString *killedApp = nil;

static BOOL animateStatusBar = YES;
static BOOL animationsEnabled = YES;
#endif
static BOOL badgeEnabled = NO;

//______________________________________________________________________________
//______________________________________________________________________________

static void loadPreferences()
{
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("persistent"), CFSTR(APP_ID));
    if (propList) {
        // NOTE: Defaults to YES
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            isPersistent = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
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

    propList = CFPreferencesCopyAppValue(CFSTR("badgeEnabled"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            badgeEnabled = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("blacklistedApplications"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFArrayGetTypeID())
            blacklistedApps = [[NSArray alloc] initWithArray:(NSArray *)propList];
        CFRelease(propList);
    }

#if 0
    CFPropertyListRef prefMethod = CFPreferencesCopyAppValue(CFSTR("invocationMethod"), CFSTR(APP_ID));
    if (prefMethod) {
        // NOTE: Defaults to HOME_SHORT_PRESS
        if ([(NSString *)prefMethod isEqualToString:@"homeDoubleTap"])
            invocationMethod = HOME_DOUBLE_TAP;
        CFRelease(prefMethod);
    }

    CFPropertyListRef prefFeedback = CFPreferencesCopyAppValue(CFSTR("feedbackType"), CFSTR(APP_ID));
    if (prefFeedback) {
        // NOTE: Defaults to SIMPLE_POPUP
        if ([(NSString *)prefFeedback isEqualToString:@"taskMenuPopup"])
            feedbackType = TASK_MENU_POPUP;
        CFRelease(prefFeedback);
    }
#endif
}

//______________________________________________________________________________
//______________________________________________________________________________

NSMutableArray *displayStacks = nil;

// Display stack names
#define SBWPreActivateDisplayStack        [displayStacks objectAtIndex:0]
#define SBWActiveDisplayStack             [displayStacks objectAtIndex:1]
#define SBWSuspendingDisplayStack         [displayStacks objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack [displayStacks objectAtIndex:3]

HOOK(SBDisplayStack, init, id)
{
    id stack = CALL_ORIG(SBDisplayStack, init);
    [displayStacks addObject:stack];
    return stack;
}

HOOK(SBDisplayStack, dealloc, void)
{
    [displayStacks removeObject:self];
    CALL_ORIG(SBDisplayStack, dealloc);
}

//______________________________________________________________________________
//______________________________________________________________________________

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

//______________________________________________________________________________
//______________________________________________________________________________

// NOTE: Only hooked when animationsEnabled == NO
HOOK(SBUIController, animateLaunchApplication$, void, id app)
{
    if ([app pid] != -1) {
        // Application is backgrounded

        // FIXME: Find a better solution for the Categories "transparent-window" issue
        if ([[app displayIdentifier] hasPrefix:@"com.bigboss.categories."]) {
            // Make sure SpringBoard dock and icons are hidden
            [[objc_getClass("SBIconController") sharedInstance] scatter:NO startTime:CFAbsoluteTimeGetCurrent()];
            [self showButtonBar:NO animate:NO action:NULL delegate:nil];
        }

        // Prevent status bar from fading in
        animateStatusBar = NO;

        // Launch without animation
        NSArray *state = [statusBarStates objectForKey:[app displayIdentifier]];
        [app setDisplaySetting:0x10 value:[state objectAtIndex:0]]; // statusBarMode
        [app setDisplaySetting:0x20 value:[state objectAtIndex:1]]; // statusBarOrienation
        // FIXME: Originally Activating (and not Active)
        [SBWActiveDisplayStack pushDisplay:app];
    } else {
        // Normal launch
        CALL_ORIG(SBUIController, animateLaunchApplication$, app);
    }
}
#endif

//______________________________________________________________________________
//______________________________________________________________________________

// The alert window displays instructions when the home button is held down
static NSTimer *invocationTimer = nil;
static BOOL invocationTimerDidFire = NO;
static id alert = nil;

static void cancelInvocationTimer()
{
    // Disable and release timer (may be nil)
    [invocationTimer invalidate];
    [invocationTimer release];
    invocationTimer = nil;
}

// NOTE: Only hooked when invocationMethod == HOME_SHORT_PRESS
HOOK(SpringBoard, menuButtonDown$, void, GSEvent *event)
{
    // FIXME: If already invoked, should not set timer... right? (needs thought)
    if (![[objc_getClass("SBAwayController") sharedAwayController] isLocked]) {
        // Not locked
        if (!alert)
            // Task menu is not visible; setup toggle-delay timer
            invocationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.7f
                target:self selector:@selector(invokeBackgrounder)
                userInfo:nil repeats:NO] retain];
        invocationTimerDidFire = NO;
    }

    CALL_ORIG(SpringBoard, menuButtonDown$, event);
}

// NOTE: Only hooked when invocationMethod == HOME_SHORT_PRESS
HOOK(SpringBoard, menuButtonUp$, void, GSEvent *event)
{
    if (!invocationTimerDidFire)
        cancelInvocationTimer();
    else if (feedbackType == SIMPLE_POPUP)
        [self dismissBackgrounderFeedback];

    CALL_ORIG(SpringBoard, menuButtonUp$, event);
}

#if 0
// NOTE: Only hooked when invocationMethod == HOME_DOUBLE_TAP
HOOK(SpringBoard, handleMenuDoubleTap, void)
{
    if (![[objc_getClass("SBAwayController") sharedAwayController] isLocked]) {
        // Not locked
        if (alert == nil) {
            // Popup not active
            if (feedbackType == TASK_MENU_POPUP ||
                    [SBWActiveDisplayStack topApplication] != nil) {
                // invoke and return
                [self invokeBackgrounder];
                return;
            }
        } else {
            // Popup is active; dismiss and perform normal behaviour
            [self dismissBackgrounderFeedback];
        }
    }

    CALL_ORIG(SpringBoard, handleMenuDoubleTap);
}

// NOTE: Only hooked when feedbackType == TASK_MENU_POPUP
HOOK(SpringBoard, _handleMenuButtonEvent, void)
{
    // Handle single tap
    if (alert) {
        // Task menu is visible
        // FIXME: with short press, the task menu may have just been invoked...
        if (invocationTimerDidFire == NO)
            // Hide and destroy the task menu
            [self dismissBackgrounderFeedback];

        // NOTE: _handleMenuButtonEvent is responsible for resetting the home tap count
        Ivar ivar = class_getInstanceVariable([self class], "_menuButtonClickCount");
        unsigned int *_menuButtonClickCount = (unsigned int *)((char *)self + ivar_getOffset(ivar));
        *_menuButtonClickCount = 0x8000;
    } else {
        CALL_ORIG(SpringBoard, _handleMenuButtonEvent);
    }
}
#endif

HOOK(SpringBoard, applicationDidFinishLaunching$, void, id application)
{
    // NOTE: SpringBoard creates five stacks at startup:
    //       - first: visible displays
    //       - third: displays being activated
    //       - xxxxx: displays being deactivated
    displayStacks = [[NSMutableArray alloc] initWithCapacity:5];

    // NOTE: The initial capacity value was chosen to hold the default active
    //       apps (MobilePhone and MobileMail) plus two others
    activeApps = [[NSMutableArray alloc] initWithCapacity:4];
    bgEnabledApps = [[NSMutableArray alloc] initWithCapacity:2];

#if 0
    // Create a dictionary to store the statusbar state for active apps
    // FIXME: Determine a way to do this without requiring extra storage
    statusBarStates = [[NSMutableDictionary alloc] initWithCapacity:5];

    if (feedbackType == TASK_MENU_POPUP)
        // Initialize task menu popup
        initTaskMenuPopup();
    else
#endif
        // Initialize simple notification popup
        initSimplePopup();

    CALL_ORIG(SpringBoard, applicationDidFinishLaunching$, application);
}

HOOK(SpringBoard, dealloc, void)
{
    //[killedApp release];
    [bgEnabledApps release];
    [activeApps release];
    [displayStacks release];
    CALL_ORIG(SpringBoard, dealloc);
}

static void $SpringBoard$invokeBackgrounder(SpringBoard *self, SEL sel)
{
    if (invocationMethod == HOME_SHORT_PRESS)
        invocationTimerDidFire = YES;

    id app = [SBWActiveDisplayStack topApplication];
    NSString *identifier = [app displayIdentifier];
    if (feedbackType == SIMPLE_POPUP) {
        if (app && ![blacklistedApps containsObject:identifier]) {
            BOOL isEnabled = [bgEnabledApps containsObject:identifier];
            [self setBackgroundingEnabled:(!isEnabled) forDisplayIdentifier:identifier];

            // Display simple popup
            NSString *status = [NSString stringWithFormat:@"Backgrounding %s",
                     (isEnabled ? "Disabled" : "Enabled")];

            alert = [[objc_getClass("BackgrounderAlertItem") alloc] initWithTitle:status message:nil];

            SBAlertItemsController *controller = [objc_getClass("SBAlertItemsController") sharedInstance];
            [controller activateAlertItem:alert];
            if (invocationMethod == HOME_DOUBLE_TAP)
                [self performSelector:@selector(dismissBackgrounderFeedback) withObject:nil afterDelay:1.0];
        }
#if 0
    } else if (feedbackType == TASK_MENU_POPUP) {
        // Display task menu popup
        NSMutableArray *array = [NSMutableArray arrayWithArray:activeApps];
        if (identifier) {
            // Is an application
        // This array will be used for "other apps", so remove the active app
        [array removeObject:identifier];

            // SpringBoard should always be first in the list of other applications
            [array insertObject:@"com.apple.springboard" atIndex:0];
        } else {
            // Is SpringBoard
            identifier = @"com.apple.springboard";
        }

        alert = [[objc_getClass("BackgrounderAlert") alloc] initWithCurrentApp:identifier otherApps:array blacklistedApps:blacklistedApps];
        [(SBAlert *)alert activate];
#endif
    }
}

static void $SpringBoard$dismissBackgrounderFeedback(SpringBoard *self, SEL sel)
{
    // FIXME: If feedback types other than simple and task-menu are added,
    //        this method will need to be updated

    // Hide and release alert window (may be nil)
    if (feedbackType == TASK_MENU_POPUP)
        [[alert display] dismiss];
    else
        [alert dismiss];
    [alert release];
    alert = nil;
}

static void $SpringBoard$setBackgroundingEnabled$forDisplayIdentifier$(SpringBoard *self, SEL sel, BOOL enable, NSString *identifier)
{
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

#if 0
static void $SpringBoard$switchToAppWithDisplayIdentifier$(SpringBoard *self, SEL sel, NSString *identifier)
{
    SBApplication *currApp = [SBWActiveDisplayStack topApplication];
    NSString *currIdent = currApp ? [currApp displayIdentifier] : @"com.apple.springboard";
    if (![currIdent isEqualToString:identifier]) {
        // Save the identifier for later use
        deactivatingApp = [currIdent copy];

        if ([identifier isEqualToString:@"com.apple.springboard"]) {
            // Switching to SpringBoard
            [[objc_getClass("SBUIController") sharedInstance] quitTopApplication:NULL];
        } else {
            // Switching to an application other than SpringBoard
            SBApplication *otherApp = [[objc_getClass("SBApplicationController") sharedInstance]
                applicationWithDisplayIdentifier:identifier];
            if (otherApp) {
                if (animationsEnabled) {
                    if ([currIdent isEqualToString:@"com.apple.springboard"]) {
                        [otherApp setActivationSetting:0x4 flag:YES]; // animated
                    } else {
                        [otherApp setActivationSetting:0x20 flag:YES]; // suspendOthers
                        [otherApp setActivationSetting:0x200 flag:YES]; // animateOthersSuspension
                        [otherApp setActivationSetting:0x20000000 flag:YES]; // appToApp
                    }
                } else {
                    // NOTE: Must set animation flag for deactivation, otherwise
                    //       application window does not disappear (reason yet unknown)
                    [currApp setDeactivationSetting:0x2 flag:YES]; // animate

                    NSArray *state = [statusBarStates objectForKey:identifier];
                    [otherApp setDisplaySetting:0x10 value:[state objectAtIndex:0]]; // statusBarMode
                    [otherApp setDisplaySetting:0x20 value:[state objectAtIndex:1]]; // statusBarOrienation

                    // Make sure SpringBoard dock and icons are hidden
                    [[objc_getClass("SBIconController") sharedInstance] scatter:NO startTime:CFAbsoluteTimeGetCurrent()];
                    [[objc_getClass("SBUIController") sharedInstance] showButtonBar:NO animate:NO action:NULL delegate:nil];

                    // Prevent status bar from fading in
                    animateStatusBar = NO;
                }
            }

            // Activate the target application
            // FIXME: Originally was Pre or Activating (and not Active)
            [(animationsEnabled ? SBWPreActivateDisplayStack : SBWActiveDisplayStack) pushDisplay:otherApp];

            if (!animationsEnabled && currApp)
                // Deactivate the current app
                [SBWSuspendingDisplayStack pushDisplay:currApp];
            else
                // Is SpringBoard
                [self dismissBackgrounderFeedback];
        }
    } else {
        // Application to switch to is same as current
        [self dismissBackgrounderFeedback];
    }
}

static void $SpringBoard$quitAppWithDisplayIdentifier$(SpringBoard *self, SEL sel, NSString *identifier)
{
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        // Is SpringBoard
        [self relaunchSpringBoard];
    } else {
        // Is an application
        SBApplication *app = [[objc_getClass("SBApplicationController") sharedInstance]
            applicationWithDisplayIdentifier:identifier];
        if (app) {
            if ([blacklistedApps containsObject:identifier]) {
                // Is blacklisted; should force-quit
                killedApp = [identifier copy];
                [app kill];
            } else {
                // Disable backgrounding for the application
                [self setBackgroundingEnabled:NO forDisplayIdentifier:identifier];

                // NOTE: Must set animation flag for deactivation, otherwise
                //       application window does not disappear (reason yet unknown)
                [app setDeactivationSetting:0x2 flag:YES]; // animate
                if (!animationsEnabled)
                    [app setDeactivationSetting:0x4000 value:[NSNumber numberWithDouble:0]]; // animation duration

                // Deactivate the application
                [SBWSuspendingDisplayStack pushDisplay:app];
            }
        }
    }
}
#endif

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SBApplication, launchSucceeded$, void, BOOL unknownFlag)
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

        if (badgeEnabled) {
            // Update the SpringBoard icon to indicate that the app is running
            SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
            UIImageView *badgeView = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:@"/Applications/Backgrounder.app/images/badge.png"]];
            [badgeView setOrigin:CGPointMake(-12.0f, 39.0f)];
            [badgeView setTag:1000];
            [icon addSubview:badgeView];
            [badgeView release];
        }

        // Track active status of application
        [activeApps addObject:identifier];
    }

    CALL_ORIG(SBApplication, launchSucceeded$, unknownFlag);
}

HOOK(SBApplication, exitedAbnormally, void)
{
    [bgEnabledApps removeObject:[self displayIdentifier]];

#if 0
    if (animationsEnabled && ![self isSystemApplication])
        [[NSFileManager defaultManager] removeItemAtPath:[self defaultImage:"Default"] error:nil];
#endif

    CALL_ORIG(SBApplication, exitedAbnormally);
}

HOOK(SBApplication, exitedCommon, void)
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

    CALL_ORIG(SBApplication, exitedCommon);
}

HOOK(SBApplication, deactivate, BOOL)
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

    BOOL isBackgrounded = [bgEnabledApps containsObject:[self displayIdentifier]];
    BOOL flag;
    if (isBackgrounded) {
        // Temporarily enable the eventOnly flag to prevent the applications's views
        // from being deallocated.
        // NOTE: Credit for this goes to phoenix3200 (author of Pandora Controls, http://phoenix-dev.com/)
        // FIXME: Run a trace on deactivate to determine why this works.
        flag = [self deactivationSetting:0x1];
        [self setDeactivationSetting:0x1 flag:YES];
    }

    BOOL result = CALL_ORIG(SBApplication, deactivate);

    if (isBackgrounded)
        // Must disable the eventOnly flag before returning, or else the application
        // will remain in the event-only display stack and prevent SpringBoard from
        // operating properly.
        // NOTE: This is the continuation of phoenix3200's fix
        [self setDeactivationSetting:0x1 flag:flag];

    return result;
}

// NOTE: Observed types:
//         0: Launch
//         1: Resume
//         2: Deactivation
//         3: Termination
HOOK(SBApplication, _startWatchdogTimerType$, void, int type)
{
    if (type != 3 || ![bgEnabledApps containsObject:[self displayIdentifier]])
        CALL_ORIG(SBApplication, _startWatchdogTimerType$, type);
}

#if 0
HOOK(SBApplication, _relaunchAfterAbnormalExit$, void, BOOL flag)
{
    if ([[self displayIdentifier] isEqualToString:killedApp]) {
        // Was killed by Backgrounder; do not allow relaunch
        [killedApp release];
        killedApp = nil;
    } else {
        CALL_ORIG(SBApplication, _relaunchAfterAbnormalExit$, flag);
    }
}

// NOTE: Only hooked when animationsEnabled == YES
HOOK(SBApplication, pathForDefaultImage$, id, char *def)
{
    return ([self isSystemApplication] || ![activeApps containsObject:[self displayIdentifier]]) ?
        CALL_ORIG(SBApplication, pathForDefaultImage$, def) :
        [NSString stringWithFormat:@"%@/Library/Caches/Snapshots/%@-Default.jpg",
            [[self seatbeltProfilePath] stringByDeletingPathExtension], [self bundleIdentifier]];
}
#endif

//______________________________________________________________________________
//______________________________________________________________________________

void initSpringBoardHooks()
{
    loadPreferences();

    Class $SBDisplayStack(objc_getClass("SBDisplayStack"));
    _SBDisplayStack$init =
        MSHookMessage($SBDisplayStack, @selector(init), &$SBDisplayStack$init);
    _SBDisplayStack$dealloc =
        MSHookMessage($SBDisplayStack, @selector(dealloc), &$SBDisplayStack$dealloc);

#if 0
    Class $SBStatusBarController(objc_getClass("SBStatusBarController"));
    _SBStatusBarController$setStatusBarMode$mode$orientation$duration$fenceID$animation$ =
        MSHookMessage($SBStatusBarController, @selector(setStatusBarMode:orientation:duration:fenceID:animation:),
            &$SBStatusBarController$setStatusBarMode$mode$orientation$duration$fenceID$animation$);

    if (!animationsEnabled) {
        Class $SBUIController(objc_getClass("SBUIController"));
        _SBUIController$animateLaunchApplication$ =
            MSHookMessage($SBUIController, @selector(animateLaunchApplication:), &$SBUIController$animateLaunchApplication$);
    }
#endif

    Class $SpringBoard(objc_getClass("SpringBoard"));
    _SpringBoard$applicationDidFinishLaunching$ =
        MSHookMessage($SpringBoard, @selector(applicationDidFinishLaunching:), &$SpringBoard$applicationDidFinishLaunching$);
    _SpringBoard$dealloc =
        MSHookMessage($SpringBoard, @selector(dealloc), &$SpringBoard$dealloc);

#if 0
    if (invocationMethod == HOME_DOUBLE_TAP) {
        _SpringBoard$handleMenuDoubleTap =
            MSHookMessage($SpringBoard, @selector(handleMenuDoubleTap), &$SpringBoard$handleMenuDoubleTap);
    } else {
#endif
        _SpringBoard$menuButtonDown$ =
            MSHookMessage($SpringBoard, @selector(menuButtonDown:), &$SpringBoard$menuButtonDown$);
        _SpringBoard$menuButtonUp$ =
            MSHookMessage($SpringBoard, @selector(menuButtonUp:), &$SpringBoard$menuButtonUp$);
#if 0
    }

    if (feedbackType == TASK_MENU_POPUP)
        _SpringBoard$_handleMenuButtonEvent =
            MSHookMessage($SpringBoard, @selector(_handleMenuButtonEvent), &$SpringBoard$_handleMenuButtonEvent);
#endif

    class_addMethod($SpringBoard, @selector(setBackgroundingEnabled:forDisplayIdentifier:),
        (IMP)&$SpringBoard$setBackgroundingEnabled$forDisplayIdentifier$, "v@:c@");
    class_addMethod($SpringBoard, @selector(invokeBackgrounder), (IMP)&$SpringBoard$invokeBackgrounder, "v@:");
    class_addMethod($SpringBoard, @selector(dismissBackgrounderFeedback), (IMP)&$SpringBoard$dismissBackgrounderFeedback, "v@:");
#if 0
    class_addMethod($SpringBoard, @selector(switchToAppWithDisplayIdentifier:), (IMP)&$SpringBoard$switchToAppWithDisplayIdentifier$, "v@:@");
    class_addMethod($SpringBoard, @selector(quitAppWithDisplayIdentifier:), (IMP)&$SpringBoard$quitAppWithDisplayIdentifier$, "v@:@");
#endif

    Class $SBApplication(objc_getClass("SBApplication"));
    _SBApplication$launchSucceeded$ =
        MSHookMessage($SBApplication, @selector(launchSucceeded:), &$SBApplication$launchSucceeded$);
    _SBApplication$deactivate =
        MSHookMessage($SBApplication, @selector(deactivate), &$SBApplication$deactivate);
    _SBApplication$exitedAbnormally =
        MSHookMessage($SBApplication, @selector(exitedAbnormally), &$SBApplication$exitedAbnormally);
    _SBApplication$exitedCommon =
        MSHookMessage($SBApplication, @selector(exitedCommon), &$SBApplication$exitedCommon);
    _SBApplication$_startWatchdogTimerType$ =
        MSHookMessage($SBApplication, @selector(_startWatchdogTimerType:), &$SBApplication$_startWatchdogTimerType$);
#if 0
    _SBApplication$_relaunchAfterAbnormalExit$ =
        MSHookMessage($SBApplication, @selector(_relaunchAfterAbnormalExit:), &$SBApplication$_relaunchAfterAbnormalExit$);
    _SBApplication$pathForDefaultImage$ =
        MSHookMessage($SBApplication, @selector(pathForDefaultImage:), &$SBApplication$pathForDefaultImage$);
#endif
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
