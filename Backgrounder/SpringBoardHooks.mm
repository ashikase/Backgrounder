/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-11-03 23:21:59
 */

/**
 * Copyright (C) 2008  Lance Fetters (aka. ashikase)
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

#include <signal.h>
#include <substrate.h>

#import <CoreFoundation/CFPreferences.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SpringBoard.h>

#import "SimplePopup.h"
#import "TaskMenuPopup.h"

struct GSEvent;


#define APP_ID "jp.ashikase.backgrounder"

// FIXME: These should be moved inside the SpringBoard class, if possible;
//        As static globals, they will exist in the UIApplication as well (?).

#define SIMPLE_POPUP 0
#define TASK_MENU_POPUP 1
static int feedbackType = SIMPLE_POPUP;

#define HOME_SHORT_PRESS 0
#define HOME_SINGLE_TAP 1
#define HOME_DOUBLE_TAP 2
static int invocationMethod = HOME_SHORT_PRESS;

static NSMutableDictionary *activeApplications = nil;
static NSMutableDictionary *statusBarStates = nil;
static NSString *switchingToApplication = nil;

static void dismissFeedback();

//______________________________________________________________________________
//______________________________________________________________________________

@interface SBDisplayStack (Backgrounder_RenamedMethods)
- (id)bg_init;
- (id)bg_dealloc;
@end

NSMutableArray *displayStacks = nil;

static id $SBDisplayStack$init(SBDisplayStack *self, SEL sel)
{
    id stack = [self bg_init];
    [displayStacks addObject:stack];
    NSLog(@"Backgrounder: initialized display stack: %@", stack);
    return stack;
}

static void $SBDisplayStack$dealloc(SBDisplayStack *self, SEL sel)
{
    [displayStacks removeObject:self];
    [self bg_dealloc];
}

//______________________________________________________________________________
//______________________________________________________________________________

@interface SBUIController (Backgrounder_RenamedMethods)
- (void)bg_animateLaunchApplication:(id)app;
@end

static void $SBUIController$animateLaunchApplication$(SBUIController *self, SEL sel, id app)
{
    if ([app pid] != -1) {
        // Application is backgrounded; don't animate
        NSArray *state = [statusBarStates objectForKey:[app displayIdentifier]];
        [app setActivationSetting:0x40 value:[state objectAtIndex:0]]; // statusbarmode
        [app setActivationSetting:0x80 value:[state objectAtIndex:1]]; // statusBarOrienation
        [[displayStacks objectAtIndex:2] pushDisplay:app];
    } else {
        // Normal launch
        [self bg_animateLaunchApplication:app];
    }
}

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

static void dismissFeedback()
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

@interface SpringBoard (Backgrounder_RenamedMethods)
- (void)bg_applicationDidFinishLaunching:(id)application;
- (void)bg_dealloc;
- (void)bg_menuButtonDown:(GSEvent *)event;
- (void)bg_menuButtonUp:(GSEvent *)event;
- (void)bg__handleMenuButtonEvent;
- (void)bg_handleMenuDoubleTap;
@end

static void $SpringBoard$menuButtonDown$(SpringBoard *self, SEL sel, GSEvent *event)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    // FIXME: If already invoked, should not set timer... right? (needs thought)
    if (invocationMethod == HOME_SHORT_PRESS) {
        if ([[displayStacks objectAtIndex:0] topApplication] != nil) {
            // Setup toggle-delay timer
            invocationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.7f
                target:self selector:@selector(invokeBackgrounder)
                userInfo:nil repeats:NO] retain];
            invocationTimerDidFire = NO;
        }
    }

    [self bg_menuButtonDown:event];
}

static void $SpringBoard$menuButtonUp$(SpringBoard *self, SEL sel, GSEvent *event)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    if (invocationMethod == HOME_SHORT_PRESS && !invocationTimerDidFire)
        // Stop activation timer
        cancelInvocationTimer();

    [self bg_menuButtonUp:event];
}

static void $SpringBoard$_handleMenuButtonEvent(SpringBoard *self, SEL sel)
{
    // Handle single tap
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    if ([[displayStacks objectAtIndex:0] topApplication] != nil) {
        // Is an application (not SpringBoard)
        Ivar ivar = class_getInstanceVariable([self class], "_menuButtonClickCount");
        unsigned int *_menuButtonClickCount = (unsigned int *)((char *)self + ivar_getOffset(ivar));
        NSLog(@"Backgrounder: current value of buttonclick is %08x", *_menuButtonClickCount);

        // FIXME: This should be rearranged/cleaned-up, if possible
        if (feedbackType == TASK_MENU_POPUP) {
        if (alert != nil) {
            // Task menu is visible
                // FIXME: with short press, the task menu may have just been
                // invoked...
                if (invocationTimerDidFire == NO)
                // Hide and destroy the task menu
                dismissFeedback();
            *_menuButtonClickCount = 0x8000;
        } else if (invocationMethod == HOME_SINGLE_TAP) {
            // Invoke Backgrounder
            [self invokeBackgrounder];
            *_menuButtonClickCount = 0x8000;
        } else {
            // Normal operation
            [self bg__handleMenuButtonEvent];
        }
        } else { // SIMPLE_POPUP
            if (invocationMethod == HOME_SINGLE_TAP) {
                [self  invokeBackgrounder];
                *_menuButtonClickCount = 0x8000;
            }
        }
    } else {
        // Is SpringBoard
        [self bg__handleMenuButtonEvent];
    }
}

static void $SpringBoard$handleMenuDoubleTap(SpringBoard *self, SEL sel)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    if ([[displayStacks objectAtIndex:0] topApplication] != nil && alert == nil)
        // Is an application and popup is not visible; toggle backgrounding
        [self invokeBackgrounder];
    else {
        // Is SpringBoard or alert is visible; perform normal behaviour
        dismissFeedback();
        [self bg_handleMenuDoubleTap];
    }
}

static void $SpringBoard$applicationDidFinishLaunching$(SpringBoard *self, SEL sel, id application)
{
    // NOTE: SpringBoard creates five stacks at startup:
    //       - first: visible displays
    //       - third: displays being activated
    //       - xxxxx: displays being deactivated
    displayStacks = [[NSMutableArray alloc] initWithCapacity:5];

    // NOTE: The initial capacity value was chosen to hold the default active
    //       apps (SpringBoard, MobilePhone, and MobileMail) plus two others
    activeApplications = [[NSMutableDictionary alloc] initWithCapacity:5];
    // SpringBoard is always active
    [activeApplications setObject:[NSNumber numberWithBool:YES] forKey:@"com.apple.springboard"];

    // Create a dictionary to store the statusbar state for active apps
    // FIXME: Determine a way to do this without requiring extra storage
    statusBarStates = [[NSMutableDictionary alloc] initWithCapacity:5];

    // Load preferences
    Class $SpringBoard(objc_getClass("SpringBoard"));
    CFPropertyListRef prefMethod = CFPreferencesCopyAppValue(CFSTR("invocationMethod"), CFSTR(APP_ID));
    if ([(NSString *)prefMethod isEqualToString:@"homeDoubleTap"]) {
        invocationMethod = HOME_DOUBLE_TAP;
        MSHookMessage($SpringBoard, @selector(handleMenuDoubleTap), (IMP)&$SpringBoard$handleMenuDoubleTap, "bg_");
    } else if ([(NSString *)prefMethod isEqualToString:@"homeSingleTap"]) {
        invocationMethod = HOME_SINGLE_TAP;
    } else {
        invocationMethod = HOME_SHORT_PRESS;
    }

    CFPropertyListRef prefFeedback = CFPreferencesCopyAppValue(CFSTR("feedbackType"), CFSTR(APP_ID));
    if ([(NSString *)prefFeedback isEqualToString:@"taskMenuPopup"]) {
        // Task menu popup
        feedbackType = TASK_MENU_POPUP;
        initTaskMenuPopup();
    } else {
        // Simple notification popup
        feedbackType = SIMPLE_POPUP;
        initSimplePopup();
    }

    [self bg_applicationDidFinishLaunching:application];
}

static void $SpringBoard$dealloc(SpringBoard *self, SEL sel)
{
    [activeApplications release];
    [displayStacks release];
    [self bg_dealloc];
}

static void $SpringBoard$invokeBackgrounder(SpringBoard *self, SEL sel)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    if (invocationMethod == HOME_SHORT_PRESS)
        invocationTimerDidFire = YES;

    id app = [[displayStacks objectAtIndex:0] topApplication];
    if (app) {
        NSString *identifier = [app displayIdentifier];
        if (feedbackType == SIMPLE_POPUP) {
            BOOL isEnabled = [[activeApplications objectForKey:identifier] boolValue];
            [self setBackgroundingEnabled:(!isEnabled) forDisplayIdentifier:identifier];

            // Display simple popup
            NSString *status = [NSString stringWithFormat:@"Backgrounding %s",
                     (isEnabled ? "Disabled" : "Enabled")];

            Class $BGAlertItem = objc_getClass("BackgrounderAlertItem");
            NSString *message = (invocationMethod == HOME_SHORT_PRESS) ? @"(Continue holding to force-quit)" : nil;
            alert = [[$BGAlertItem alloc] initWithTitle:status message:message];

            Class $SBAlertItemsController(objc_getClass("SBAlertItemsController"));
            SBAlertItemsController *controller = [$SBAlertItemsController sharedInstance];
            [controller activateAlertItem:alert];
        } else if (feedbackType == TASK_MENU_POPUP) {
            // Display task menu popup
            NSMutableArray *array = [NSMutableArray arrayWithArray:[activeApplications allKeys]];
            // This array will be used for "other apps", so remove the active app
            [array removeObject:identifier];
            // SpringBoard should always be first in the list
            int index = [array indexOfObject:@"com.apple.springboard"];
            [array exchangeObjectAtIndex:index withObjectAtIndex:0];

            Class $SBAlert = objc_getClass("BackgrounderAlert");
            alert = [[$SBAlert alloc] initWithCurrentApp:identifier otherApps:array];
            [alert activate];
        }
    }
}

static void $SpringBoard$setBackgroundingEnabled$forDisplayIdentifier$(SpringBoard *self, SEL sel, BOOL enable, NSString *identifier)
{
    NSNumber *object = [activeApplications objectForKey:identifier];
    if (object != nil) {
        BOOL isEnabled = [object boolValue];
        if (isEnabled != enable) {
            // Tell the application to change its backgrounding status
            Class $SBApplicationController(objc_getClass("SBApplicationController"));
            SBApplicationController *appCont = [$SBApplicationController sharedInstance];
            SBApplication *app = [appCont applicationWithDisplayIdentifier:identifier];
            // FIXME: If the target application does not have the Backgrounder
            //        hooks enabled, this will cause it to exit abnormally
            kill([app pid], SIGUSR1);

            // Store the new backgrounding status of the application
            [activeApplications setObject:[NSNumber numberWithBool:(!isEnabled)]
                forKey:identifier];
        }
    }
}

static void $SpringBoard$switchToAppWithDisplayIdentifier$(SpringBoard *self, SEL sel, NSString *identifier)
{
    // If the current app will be backgrounded, store the status bar state
    NSString *currIdent = [[[displayStacks objectAtIndex:0] topApplication] displayIdentifier];
    if ([activeApplications objectForKey:currIdent]) {
        Class $SBStatusBarController(objc_getClass("SBStatusBarController"));
        SBStatusBarController *sbCont = [$SBStatusBarController sharedStatusBarController];
        NSNumber *mode = [NSNumber numberWithInt:[sbCont statusBarMode]];
        NSNumber *orientation = [NSNumber numberWithInt:[sbCont statusBarOrientation]];
        [statusBarStates setObject:[NSArray arrayWithObjects:mode, orientation, nil] forKey:currIdent];
    }

    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        //dismissFeedback();

        Class $SBUIController(objc_getClass("SBUIController"));
        SBUIController *uiCont = [$SBUIController sharedInstance];
        [uiCont quitTopApplication];
    } else {
        // NOTE: Must set animation flag for deactivation, otherwise
        //       application window does not disappear (reason yet unknown)
        SBApplication *currApp = [[displayStacks objectAtIndex:0] topApplication];
        [currApp setDeactivationSetting:0x2 flag:YES]; // animate
        //[currApp setDeactivationSetting:0x400 flag:YES]; // returnToLastApp
        //[currApp setDeactivationSetting:0x10000 flag:YES]; // appToApp
        //[currApp setDeactivationSetting:0x0100 value:[NSNumber numberWithDouble:0.1]]; // animation scale
        //[currApp setDeactivationSetting:0x4000 value:[NSNumber numberWithDouble:0.4]]; // animation duration
        //[currApp setDeactivationSetting:0x0100 value:[NSNumber numberWithDouble:1.0]]; // animation scale
        //[currApp setDeactivationSetting:0x4000 value:[NSNumber numberWithDouble:0]]; // animation duration

        // Save the identifier for later use
        switchingToApplication = [identifier copy];

        if (![identifier isEqualToString:@"com.apple.springboard"]) {
            // Switching to an application other than SpringBoard
            Class $SBApplicationController(objc_getClass("SBApplicationController"));
            SBApplicationController *appCont = [$SBApplicationController sharedInstance];
            SBApplication *otherApp = [appCont applicationWithDisplayIdentifier:identifier];

            if (otherApp) {
                //[otherApp setActivationSetting:0x4 flag:YES]; // animated
                // NOTE: setting lastApp and appToApp (and the related
                //       deactivation flags above) gives an interesting
                //       switching effect; however, it does not seem to work
                //       with animatedNoPNG, and thus makes it appear that the
                //       application being switched to has been restarted.
                //[otherApp setActivationSetting:0x20000 flag:YES]; // animatedNoPNG
                //[otherApp setActivationSetting:0x10000 flag:YES]; // lastApp
                //[otherApp setActivationSetting:0x20000000 flag:YES]; // appToApp
                NSArray *state = [statusBarStates objectForKey:identifier];
                [otherApp setActivationSetting:0x40 value:[state objectAtIndex:0]]; // statusbarmode
                [otherApp setActivationSetting:0x80 value:[state objectAtIndex:1]]; // statusBarOrienation

                // Activate the new app
                [[displayStacks objectAtIndex:2] pushDisplay:otherApp];
            }
        }

        // Deactivate the current app
        [[displayStacks objectAtIndex:3] pushDisplay:currApp];
    }
}

static void $SpringBoard$quitAppWithDisplayIdentifier$(SpringBoard *self, SEL sel,NSString *identifier)
{
    Class $SBApplicationController(objc_getClass("SBApplicationController"));
    SBApplicationController *appCont = [$SBApplicationController sharedInstance];
    SBApplication *app = [appCont applicationWithDisplayIdentifier:identifier];

    if (app) {
        // Disable backgrounding for the application
        [self setBackgroundingEnabled:NO forDisplayIdentifier:identifier];

        // NOTE: Must set animation flag for deactivation, otherwise
        //       application window does not disappear (reason yet unknown)
        [app setDeactivationSetting:0x2 flag:YES]; // animate
        [app setDeactivationSetting:0x4000 value:[NSNumber numberWithDouble:0]]; // animation duration

        // Deactivate the application
        [[displayStacks objectAtIndex:3] pushDisplay:app];
    }
}

//______________________________________________________________________________
//______________________________________________________________________________

@interface SBApplication (Backgrounder_RenamedMethods)
- (BOOL)bg_shouldLaunchPNGless;
- (void)bg_launchSucceeded;
- (void)bg_exitedCommon;
- (BOOL)bg_deactivate;
- (void)bg_deactivated;
- (void)bg__startTerminationWatchdogTimer;
@end

static BOOL $SBApplication$shouldLaunchPNGless(SBApplication *self, SEL sel)
{
    // Only show splash-screen on initial launch
    return ([self pid] != -1) ? YES : [self bg_shouldLaunchPNGless];
}

static void $SBApplication$launchSucceeded(SBApplication *self, SEL sel)
{
    NSString *identifier = [self displayIdentifier];
    if ([activeApplications objectForKey:identifier] == nil) {
        // Initial launch; check if this application defaults to backgrounding
        CFPropertyListRef array = CFPreferencesCopyAppValue(CFSTR("enabledApplications"), CFSTR(APP_ID));
        if ([(NSArray *)array containsObject:identifier]) {
            // Tell the application to enable backgrounding
            kill([self pid], SIGUSR1);

            // Store the backgrounding status of the application
            [activeApplications setObject:[NSNumber numberWithBool:YES] forKey:identifier];
        } else {
            [activeApplications setObject:[NSNumber numberWithBool:NO] forKey:identifier];
        }
    }

    [self bg_launchSucceeded];
}

static void $SBApplication$exitedCommon(SBApplication *self, SEL sel)
{
    // Application has exited (either normally or abnormally);
    // remove from active applications list
    NSString *identifier = [self displayIdentifier];
    [activeApplications removeObjectForKey:identifier];

    // ... also remove status bar state data from states list
    [statusBarStates removeObjectForKey:identifier];

    [self bg_exitedCommon];
}

static BOOL $SBApplication$deactivate(SBApplication *self, SEL sel)
{
    if (![self deactivationSetting:0x10000]) // appToApp
        // Switching to SpringBoard; hide feedback before deactivating
        dismissFeedback();

        // If the app will be backgrounded, store the status bar state
        NSString *identifier = [self displayIdentifier];
        if ([activeApplications objectForKey:identifier]) {
            Class $SBStatusBarController(objc_getClass("SBStatusBarController"));
            SBStatusBarController *sbCont = [$SBStatusBarController sharedStatusBarController];
            NSNumber *mode = [NSNumber numberWithInt:[sbCont statusBarMode]];
            NSNumber *orientation = [NSNumber numberWithInt:[sbCont statusBarOrientation]];
            [statusBarStates setObject:[NSArray arrayWithObjects:mode, orientation, nil] forKey:identifier];
        }

    return [self bg_deactivate];
}

static void $SBApplication$deactivated(SBApplication *self, SEL sel)
{
    if ([self deactivationSetting:0x10000]) // appToApp
        // Switching to another application; hide feedback now that deactivated
        dismissFeedback();
    [self bg_deactivated];
}

static void $SBApplication$_startTerminationWatchdogTimer(SBApplication *self, SEL sel)
{
    BOOL isBackgroundingEnabled = [[activeApplications objectForKey:[self displayIdentifier]] boolValue];
    if (!isBackgroundingEnabled)
        [self bg__startTerminationWatchdogTimer];
}

//______________________________________________________________________________
//______________________________________________________________________________

void initSpringBoardHooks()
{
    Class $SBDisplayStack(objc_getClass("SBDisplayStack"));
    MSHookMessage($SBDisplayStack, @selector(init), (IMP)&$SBDisplayStack$init, "bg_");
    MSHookMessage($SBDisplayStack, @selector(dealloc), (IMP)&$SBDisplayStack$dealloc, "bg_");

    Class $SBUIController(objc_getClass("SBUIController"));
    MSHookMessage($SBUIController, @selector(animateLaunchApplication:), (IMP)&$SBUIController$animateLaunchApplication$, "bg_");

    Class $SpringBoard(objc_getClass("SpringBoard"));
    MSHookMessage($SpringBoard, @selector(applicationDidFinishLaunching:), (IMP)&$SpringBoard$applicationDidFinishLaunching$, "bg_");
    MSHookMessage($SpringBoard, @selector(dealloc), (IMP)&$SpringBoard$dealloc, "bg_");
    MSHookMessage($SpringBoard, @selector(menuButtonDown:), (IMP)&$SpringBoard$menuButtonDown$, "bg_");
    MSHookMessage($SpringBoard, @selector(menuButtonUp:), (IMP)&$SpringBoard$menuButtonUp$, "bg_");
    MSHookMessage($SpringBoard, @selector(_handleMenuButtonEvent), (IMP)&$SpringBoard$_handleMenuButtonEvent, "bg_");
    class_addMethod($SpringBoard, @selector(setBackgroundingEnabled:forDisplayIdentifier:),
        (IMP)&$SpringBoard$setBackgroundingEnabled$forDisplayIdentifier$, "v@:c@");
    class_addMethod($SpringBoard, @selector(invokeBackgrounder), (IMP)&$SpringBoard$invokeBackgrounder, "v@:");
    class_addMethod($SpringBoard, @selector(switchToAppWithDisplayIdentifier:), (IMP)&$SpringBoard$switchToAppWithDisplayIdentifier$, "v@:@");
    class_addMethod($SpringBoard, @selector(quitAppWithDisplayIdentifier:), (IMP)&$SpringBoard$quitAppWithDisplayIdentifier$, "v@:@");

    Class $SBApplication(objc_getClass("SBApplication"));
    MSHookMessage($SBApplication, @selector(shouldLaunchPNGless), (IMP)&$SBApplication$shouldLaunchPNGless, "bg_");
    MSHookMessage($SBApplication, @selector(launchSucceeded), (IMP)&$SBApplication$launchSucceeded, "bg_");
    MSHookMessage($SBApplication, @selector(deactivate), (IMP)&$SBApplication$deactivate, "bg_");
    MSHookMessage($SBApplication, @selector(deactivated), (IMP)&$SBApplication$deactivated, "bg_");
    MSHookMessage($SBApplication, @selector(exitedCommon), (IMP)&$SBApplication$exitedCommon, "bg_");
    MSHookMessage($SBApplication, @selector(_startTerminationWatchdogTimer), (IMP)&$SBApplication$_startTerminationWatchdogTimer, "bg_");
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
