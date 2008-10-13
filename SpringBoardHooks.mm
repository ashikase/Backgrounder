/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-13 16:25:46
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

#include <signal.h>
#include <substrate.h>

#import <CoreFoundation/CFPreferences.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBDisplayStack.h>
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

static BOOL shouldSuspend = YES;

NSMutableDictionary *activeApplications = nil;

//______________________________________________________________________________
//______________________________________________________________________________

@protocol BackgrounderSBStack
- (id)bg_init;
@end

static SBDisplayStack *displayStack = nil;

static id $SBDisplayStack$init(SBDisplayStack<BackgrounderSBStack> *self, SEL sel)
{
    // NOTE: SpringBoard appears to create five stacks at startup;
    //       the first stack is for applications (the others, unknown)
    id ret = [self bg_init];
    if (!displayStack)
        displayStack = ret;
    return ret;
}

//______________________________________________________________________________
//______________________________________________________________________________

// The alert window displays instructions when the home button is held down
static NSTimer *activationTimer = nil;
static id alert = nil;

static void cancelActivationTimer()
{
    // Disable and release timer (may be nil)
    [activationTimer invalidate];
    [activationTimer release];
    activationTimer = nil;
}

static void dismissFeedback()
{
    // Hide and release alert window (may be nil)
    if (feedbackType != TASK_MENU_POPUP) {
        [alert dismiss];
        [alert release];
    }
    alert = nil;
}

@protocol BackgrounderSB
- (void)bg_applicationDidFinishLaunching:(id)application;
- (void)bg_dealloc;
- (void)bg_menuButtonDown:(GSEvent *)event;
- (void)bg_menuButtonUp:(GSEvent *)event;
- (void)bg__handleMenuButtonEvent;
- (void)bg_handleMenuDoubleTap;
- (void)backgrounderActivate;
@end

static void $SpringBoard$backgrounderActivate(id self, SEL sel)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    id app = [displayStack topApplication];
    if (app) {
        NSString *identifier = [app displayIdentifier];
        if (feedbackType == SIMPLE_POPUP) {
            // Tell the application to toggle backgrounding
            kill([app pid], SIGUSR1);

            // Store the backgrounding status of the application
            BOOL isEnabled = [[activeApplications objectForKey:identifier] boolValue];
            [activeApplications setObject:[NSNumber numberWithBool:(!isEnabled)]
                forKey:identifier];

            // Display simple popup
            NSString *status = [NSString stringWithFormat:@"Backgrounding %s",
                     (isEnabled ? "Disabled" : "Enabled")];

            Class $BGAlertItem = objc_getClass("BackgrounderAlertItem");
            alert = [[$BGAlertItem alloc] initWithTitle:status
                message:@"(Continue holding to force-quit)"];

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
            alert = [[[$SBAlert alloc] initWithCurrentApp:identifier otherApps:array] autorelease];
            [alert activate];
        }
    }
}

static void $SpringBoard$menuButtonDown$(SpringBoard<BackgrounderSB> *self, SEL sel, GSEvent *event)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    if (invocationMethod == HOME_SHORT_PRESS) {
        if ([displayStack topApplication] != nil)
            // Setup toggle-delay timer
            activationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.7f
                target:self selector:@selector(backgrounderActivate)
                userInfo:nil repeats:NO] retain];
    }

    [self bg_menuButtonDown:event];
}

static void $SpringBoard$menuButtonUp$(SpringBoard<BackgrounderSB> *self, SEL sel, GSEvent *event)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    if (invocationMethod == HOME_SHORT_PRESS)
        // Stop activation timer (assuming that it has not already fired)
        cancelActivationTimer();

    [self bg_menuButtonUp:event];
}

static void $SpringBoard$_handleMenuButtonEvent(SpringBoard<BackgrounderSB> *self, SEL sel)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    if ([displayStack topApplication] != nil) {
        Ivar ivar = class_getInstanceVariable([self class], "_menuButtonClickCount");
        unsigned int *_menuButtonClickCount = (unsigned int *)((char *)self + ivar_getOffset(ivar));

        // FIXME: This should be rearranged/cleaned-up, if possible
        if (feedbackType == TASK_MENU_POPUP && alert != nil) {
            // Hide and destroy the popup
            dismissFeedback();
            *_menuButtonClickCount = 0x8000;
            return;
        } else if (invocationMethod == HOME_SINGLE_TAP) {
            [self  backgrounderActivate];
        } else if (invocationMethod == HOME_SHORT_PRESS && !shouldSuspend) {
            *_menuButtonClickCount = 0x8000;
            return;
        }
    }

    [self bg__handleMenuButtonEvent];
}

static void $SpringBoard$handleMenuDoubleTap(SpringBoard<BackgrounderSB> *self, SEL sel)
{
    NSLog(@"Backgrounder: %s", __FUNCTION__);

    if ([displayStack topApplication] != nil && alert == nil)
        // Is an application and popup is not visible; toggle backgrounding
        [self backgrounderActivate];
    else {
        // Is SpringBoard or alert is visible; perform normal behaviour
        dismissFeedback();
        [self bg_handleMenuDoubleTap];
    }
}

static void $SpringBoard$applicationDidFinishLaunching$(SpringBoard<BackgrounderSB> *self, SEL sel, id application)
{
    // NOTE: The initial capacity value was chosen to hold the default active
    //       apps (SpringBoard, MobilePhone, and MobileMail) plus two others
    activeApplications = [[NSMutableDictionary alloc] initWithCapacity:5];
    // SpringBoard is always active
    [activeApplications setObject:[NSNumber numberWithBool:YES] forKey:@"com.apple.springboard"];

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

static void $SpringBoard$dealloc(SpringBoard<BackgrounderSB> *self, SEL sel)
{
    [activeApplications release];
    [self bg_dealloc];
}

//______________________________________________________________________________
//______________________________________________________________________________

@protocol BackgrounderSBApp
- (BOOL)bg_shouldLaunchPNGless;
- (void)bg_launchSucceeded;
- (void)bg_exitedCommon;
- (BOOL)bg_kill;
- (void)bg__startTerminationWatchdogTimer;
@end

static BOOL $SBApplication$shouldLaunchPNGless(SBApplication<BackgrounderSBApp> *self, SEL sel)
{
    // Only show splash-screen on initial launch
    return ([self pid] != -1) ? YES : [self bg_shouldLaunchPNGless];
}

static void $SBApplication$launchSucceeded(SBApplication<BackgrounderSBApp> *self, SEL sel)
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

static void $SBApplication$exitedCommon(SBApplication<BackgrounderSBApp> *self, SEL sel)
{
    // Application has exited (either normally or abnormally);
    // remove from active applications list
    NSString *identifier = [self displayIdentifier];
    [activeApplications removeObjectForKey:identifier];

    [self bg_exitedCommon];
}

static BOOL $SBApplication$kill(SBApplication<BackgrounderSBApp> *self, SEL sel)
{
    // Hide and destroy the popup alert
    dismissFeedback();
    return [self bg_kill];
}

static void $SBApplication$_startTerminationWatchdogTimer(SBApplication<BackgrounderSBApp> *self, SEL sel)
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

    Class $SpringBoard(objc_getClass("SpringBoard"));
    MSHookMessage($SpringBoard, @selector(applicationDidFinishLaunching:), (IMP)&$SpringBoard$applicationDidFinishLaunching$, "bg_");
    MSHookMessage($SpringBoard, @selector(dealloc), (IMP)&$SpringBoard$dealloc, "bg_");
    MSHookMessage($SpringBoard, @selector(menuButtonDown:), (IMP)&$SpringBoard$menuButtonDown$, "bg_");
    MSHookMessage($SpringBoard, @selector(menuButtonUp:), (IMP)&$SpringBoard$menuButtonUp$, "bg_");
    MSHookMessage($SpringBoard, @selector(_handleMenuButtonEvent), (IMP)&$SpringBoard$_handleMenuButtonEvent, "bg_");
    class_addMethod($SpringBoard, @selector(backgrounderActivate), (IMP)&$SpringBoard$backgrounderActivate, "v@:");

    Class $SBApplication(objc_getClass("SBApplication"));
    MSHookMessage($SBApplication, @selector(shouldLaunchPNGless), (IMP)&$SBApplication$shouldLaunchPNGless, "bg_");
    MSHookMessage($SBApplication, @selector(launchSucceeded), (IMP)&$SBApplication$launchSucceeded, "bg_");
    MSHookMessage($SBApplication, @selector(exitedCommon), (IMP)&$SBApplication$exitedCommon, "bg_");
    MSHookMessage($SBApplication, @selector(kill), (IMP)&$SBApplication$kill, "bg_");
    MSHookMessage($SBApplication, @selector(_startTerminationWatchdogTimer), (IMP)&$SBApplication$_startTerminationWatchdogTimer, "bg_");
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
