/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-12-12 14:44:42
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

#import <UIKit/UIKit.h>


#define TP() NSLog(@"=== @%s:%u[%s]\n",  __FILE__, __LINE__, __FUNCTION__);

typedef struct __GSEvent *GSEventRef;

//==============================================================================

// NOTE: This struct comes from UIApplication

// Firmware 3.0 - 3.2.
// NOTE: This declaration is incomplete.
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
    unsigned shouldExitAfterTaskCompletion : 1;
    unsigned terminating : 1;
    unsigned isHandlingShortCutURL : 1;
    unsigned idleTimerDisabled : 1;
    unsigned deviceOrientation : 3;
    unsigned delegateShouldBeReleasedUponSet : 1;
    unsigned delegateHandleOpenURL : 1;
    unsigned delegateDidReceiveMemoryWarning : 1;
    unsigned delegateWillTerminate : 1;
    unsigned delegateSignificantTimeChange : 1;
    unsigned delegateWillChangeInterfaceOrientation : 1;
    unsigned delegateDidChangeInterfaceOrientation : 1;
    unsigned delegateWillChangeStatusBarFrame : 1;
    unsigned delegateDidChangeStatusBarFrame : 1;
    unsigned delegateDeviceAccelerated : 1;
    unsigned delegateDeviceChangedOrientation : 1;
    unsigned delegateDidBecomeActive : 1;
    unsigned delegateWillResignActive : 1;
    unsigned delegateDidEnterBackground : 1;
    unsigned delegateWillEnterForeground : 1;
    unsigned delegateWillSuspend : 1;
    unsigned delegateDidResume : 1;
    unsigned idleTimerDisableActive : 1;
    unsigned userDefaultsSyncDisabled : 1;
    unsigned headsetButtonClickCount : 4;
    unsigned isHeadsetButtonDown : 1;
    unsigned isFastForwardActive : 1;
    unsigned isRewindActive : 1;
    unsigned disableViewGroupOpacity : 1;
    unsigned disableViewEdgeAntialiasing : 1;
    unsigned shakeToEdit : 1;
    unsigned isClassic : 1;
    unsigned zoomInClassicMode : 1;
    unsigned ignoreHeadsetClicks : 1;
    unsigned touchRotationDisabled : 1;
    unsigned taskSuspendingUnsupported : 1;
    unsigned isUnitTests : 1;
    unsigned disableViewContentScaling : 1;
} UIApplicationFlags4x;

// Firmware 5.0
typedef struct {
    unsigned int deactivatingReasonFlags:8;
    unsigned int isSuspended:1;
    unsigned int isSuspendedEventsOnly:1;
    unsigned int isLaunchedSuspended:1;
    unsigned int calledNonSuspendedLaunchDelegate:1;
    unsigned int isHandlingURL:1;
    unsigned int isHandlingRemoteNotification:1;
    unsigned int isHandlingLocalNotification:1;
    unsigned int statusBarShowsProgress:1;
    unsigned int statusBarRequestedStyle:4;
    unsigned int statusBarHidden:1;
    unsigned int blockInteractionEvents:4;
    unsigned int receivesMemoryWarnings:1;
    unsigned int showingProgress:1;
    unsigned int receivesPowerMessages:1;
    unsigned int launchEventReceived:1;
    unsigned int systemIsAnimatingApplicationLifecycleEvent:1;
    unsigned int isResuming:1;
    unsigned int isSuspendedUnderLock:1;
    unsigned int shouldExitAfterSendSuspend:1;
    unsigned int shouldExitAfterTaskCompletion:1;
    unsigned int terminating:1;
    unsigned int isHandlingShortCutURL:1;
    unsigned int idleTimerDisabled:1;
    unsigned int deviceOrientation:3;
    unsigned int delegateShouldBeReleasedUponSet:1;
    unsigned int delegateHandleOpenURL:1;
    unsigned int delegateOpenURL:1;
    unsigned int delegateDidReceiveMemoryWarning:1;
    unsigned int delegateWillTerminate:1;
    unsigned int delegateSignificantTimeChange:1;
    unsigned int delegateWillChangeInterfaceOrientation:1;
    unsigned int delegateDidChangeInterfaceOrientation:1;
    unsigned int delegateWillChangeStatusBarFrame:1;
    unsigned int delegateDidChangeStatusBarFrame:1;
    unsigned int delegateDeviceAccelerated:1;
    unsigned int delegateDeviceChangedOrientation:1;
    unsigned int delegateDidBecomeActive:1;
    unsigned int delegateWillResignActive:1;
    unsigned int delegateDidEnterBackground:1;
    unsigned int delegateDidEnterBackgroundWasSent:1;
    unsigned int delegateWillEnterForeground:1;
    unsigned int delegateWillSuspend:1;
    unsigned int delegateDidResume:1;
    unsigned int userDefaultsSyncDisabled:1;
    unsigned int headsetButtonClickCount:4;
    unsigned int isHeadsetButtonDown:1;
    unsigned int isFastForwardActive:1;
    unsigned int isRewindActive:1;
    unsigned int disableViewGroupOpacity:1;
    unsigned int disableViewEdgeAntialiasing:1;
    unsigned int shakeToEdit:1;
    unsigned int isClassic:1;
    unsigned int zoomInClassicMode:1;
    unsigned int ignoreHeadsetClicks:1;
    unsigned int touchRotationDisabled:1;
    unsigned int taskSuspendingUnsupported:1;
    unsigned int taskSuspendingOnLockUnsupported:1;
    unsigned int isUnitTests:1;
    unsigned int requiresHighResolution:1;
    unsigned int disableViewContentScaling:1;
    unsigned int singleUseLaunchOrientation:3;
    unsigned int defaultInterfaceOrientation:3;
    unsigned int delegateWantsNextResponder:1;
    unsigned int isRunningInApplicationSwitcher:1;
    unsigned int isSendingEventForProgrammaticTouchCancellation:1;
} UIApplicationFlags5x;

//==============================================================================

@interface UIApplication (Private)
- (void)addStatusBarImageNamed:(id)named;
- (NSString *)displayIdentifier;
- (void)removeStatusBarImageNamed:(id)named;
- (void)terminateWithSuccess;
@end
@interface UIApplication (Firmware4x)
- (id)_backgroundModes;
- (void)endBackgroundTask:(unsigned)task;
@end

@interface UIModalView : UIView
@property(copy, nonatomic) NSString *message;
@property(copy, nonatomic) NSString *title;
- (void)setNumberOfRows:(int)rows;
@end

//==============================================================================

@protocol UIModalViewDelegate @end
@interface SBAlertItem : NSObject <UIModalViewDelegate>
- (id)alertSheet;
- (void)dismiss;
@end

@interface SBAlertItemsController : NSObject
+ (id)sharedInstance;
- (void)activateAlertItem:(id)item;
@end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (id)applicationWithDisplayIdentifier:(id)displayIdentifier;
@end

@class SBProcess;
@interface SBDisplay : NSObject
- (BOOL)activationSetting:(unsigned)setting;
- (void)clearActivationSettings;
- (BOOL)deactivationSetting:(unsigned)setting;                               // ~Firmware 4
- (BOOL)deactivationFlag:(unsigned int)setting;                              // Firmware 5~
- (BOOL)displaySetting:(unsigned)setting;                                    // ~Firmware 4
- (BOOL)displayFlag:(unsigned int)setting;                                   // Firmware 5~
- (void)setDeactivationSetting:(unsigned)setting flag:(BOOL)flag;
- (void)setDeactivationSetting:(unsigned int)setting value:(id)value;        // Firmware 4~
- (void)kill;
@end
@interface SBApplication : SBDisplay
- (void)_cancelAutoRelaunch;
- (id)contextHostView;                                                       // ~Firmware 4
- (id)contextHostManager;                                                    // Firmware 5~
- (id)displayIdentifier;
- (BOOL)isSystemApplication;
@end
@interface SBAppContextHostManager : NSObject {
    //SBAppContextHostView *_contextHostView;
}
@end
@interface SBApplication (Firmware3x)
@property(assign) int pid;
@end
@interface SBApplication (Firmware4x)
@property(retain) SBProcess *process;
- (void)setSuspendType:(int)type;
- (BOOL)supportsAudioBackgroundMode;
- (BOOL)supportsLocationBackgroundMode;
- (BOOL)supportsVOIPBackgroundMode;
- (BOOL)supportsContinuousBackgroundMode;
@end
@interface SBApplication (FirmwarePre42)
- (int)_suspensionType;
@end
@interface SBApplication (Firmware42x)
- (int)suspensionType;
@end
@interface SBApplication (Firmware5x)
- (id)contextHostViewForRequester:(id)fp8;
@end

@interface SBDisplayStack : NSObject
- (BOOL)containsDisplay:(id)display;
- (id)popDisplay:(id)display;
- (void)pushDisplay:(id)display;
- (id)topApplication;
@end

@interface SBIcon : UIView @end
@interface SBIcon (Firmware32x)
+ (CGSize)defaultIconImageSize;
@end
@interface SBApplicationIcon : SBIcon
- (SBApplication *)application;
@end

@interface SBIconModel : NSObject
+ (id)sharedInstance;
@end
@interface SBIconModel (Firmware3x)
- (id)iconForDisplayIdentifier:(id)displayIdentifier;
@end
@interface SBIconModel (Firmware4x)
- (id)leafIconForIdentifier:(id)identifier; 
@end
@interface SBIconViewMap : NSObject
+ (id)homescreenMap;
- (id)iconViewForIcon:(id)fp8;
@end
@interface SBIconView : UIView
+ (CGSize)defaultIconImageSize;
- (int)location;
- (id)icon;
- (id)iconImageView;
@end

@interface SBProcess : NSObject
@property(readonly, assign) int pid;
- (BOOL)isRunning;                                            // Firmware 4
@end

@protocol SBWiFiManagerDelegate @end
@interface SpringBoard : UIApplication <UIApplicationDelegate, SBWiFiManagerDelegate>
- (void)_setLockButtonTimer:(id)timer;
@end
@interface SpringBoard (Firmware3x)
- (void)_unsetLockButtonBearTrap;
@end

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
