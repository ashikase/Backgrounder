/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-02 21:01:54
 *
 * Description:
 * ------------
 *   This is an extension to SpringBoard that allows applications
 *   to run in the background (instead of terminating).
 *
 * Usage:
 * ------
 *   The list of background-enabled applications is retrieved from the
 *   following preferences file:
 *
 *   /var/mobile/Library/Preferences/jp.ashikase.backgrounder.plist
 *
 *   The file should be created with the following format, where the <string>
 *   values represent the bundle identifiers of the applications that are to
 *   be enabled:
 *
 *   <?xml version="1.0" encoding="UTF-8"?>
 *   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 *   <plist version="1.0">
 *   <dict>
 *   	<key>enabled_apps</key>
 *   	<array>
 *   		<string>com.apple.weather</string>
 *   		<string>com.apple.calculator</string>
 *   	</array>
 *   </dict>
 *   </plist>
 *
 * Limitations:
 * ------------
 *   There is currently no way to terminate a background-enabled application,
 *   other than killing it (by holding the Home button for 5-6 seconds or
 *   using /bin/kill or /usr/bin/killall).
 *
 *   Some applications may use the suspend/resume methods to perform important
 *   tasks, such as saving preferences. If the application is not properly
 *   terminated, these tasks may never be run.
 *
 * Todo:
 * -----
 * - add a method for proper termination of a background-enabled app.
 * - add a method to quickly enable/disable backgrounding of an app.
 *
 * Compilation:
 * ------------
 *   This code requires the MobileSubstrate library and headers;
 *   the MobileSubstrate source can be obtained via Subversion at:
 *   http://svn.saurik.com/repos/menes/trunk/mobilesubstrate
 *
 *   Compile with following command:
 *
 *   arm-apple-darwin-g++ -dynamiclib -O2 -Wall -Werror -o Backgrounder.dylib \
 *   Backgrounder.mm -init _BackgrounderInitialize -lobjc -framework CoreFoundation \
 *   -framework Foundation -framework UIKit \
 *   -F${IPHONE_SYS_ROOT}/System/Library/PrivateFrameworks \
 *   -I$(MOBILESUBTRATE_INCLUDE_PATH) -L$(MOBILESUBTRATE_LIB_PATH) -lsubstrate
 *
 *   The resulting Backgrounder.dylib should be placed on the iPhone/Pod
 *   under /Library/MobileSubstrate/DynamicLibraries/
 *
 * Acknowledgements:
 * -----------------
 *   Thanks go out to Jay Freeman (saurik) for his work on MobileSubstrate
 *   (and all things iPhone).
 */

#include <objc/message.h>
#include <signal.h>
#include <substrate.h>

#import <GraphicsServices/GraphicsServices.h>

#import <CoreFoundation/CFNotificationCenter.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSThread.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBAlertItem.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SpringBoard.h>

#import <UIKit/UIApplication.h>
#import <UIKit/UIColor.h>
#import <UIKit/UILabel.h>
#import <UIKit/UIModalView.h>
#import <UIKit/UIModalView-Private.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIView.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>
#import <UIKit/UIWindow.h>

#define NOTICE_ENABLED "jp.ashikase.backgrounder.enabled"
#define NOTICE_DISABLED "jp.ashikase.backgrounder.disabled"


// -----------------------------------------------------------------------------
// --------------------------- CUSTOM ALERT ITEM -------------------------------
// -----------------------------------------------------------------------------

@interface BackgrounderAlertItem : SBAlertItem
{
    NSString *title;
    NSString *message;
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message;
- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)passcode;

@end

static id $BackgrounderAlertItem$initWithTitle$message$(id self, SEL sel, NSString *title, NSString *message)
{
    Class $SBAlertItem = objc_getClass("SBAlertItem");
    objc_super $super = {self, $SBAlertItem};
    self = objc_msgSendSuper(&$super, @selector(init));
    if (self) {
        object_setInstanceVariable(self, "title", reinterpret_cast<void *>([title copy])); 
        object_setInstanceVariable(self, "message", reinterpret_cast<void *>([message copy])); 
    }
    return self;
}

static void $BackgrounderAlertItem$dealloc(id self, SEL sel)
{
    NSString *title = nil, *message = nil;
    object_getInstanceVariable(self, "title", reinterpret_cast<void **>(&title));
    object_getInstanceVariable(self, "message", reinterpret_cast<void **>(&message));
    [title release];
    [message release];

    Class $SBAlertItem = objc_getClass("SBAlertItem");
    objc_super $super = {self, $SBAlertItem};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

static void $BackgrounderAlertItem$configure$requirePasscodeForActions$(id self, SEL sel, BOOL configure, BOOL passcode)
{
    NSString *title = nil, *message = nil;
    object_getInstanceVariable(self, "title", reinterpret_cast<void **>(&title));
    object_getInstanceVariable(self, "message", reinterpret_cast<void **>(&message));
    UIModalView *view = [self alertSheet];
    [view setTitle:title];
    [view setMessage:message];
}

// -----------------------------------------------------------------------------
// ------------------------------ SPRINGBOARD ----------------------------------
// -----------------------------------------------------------------------------

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

static BOOL alertTimerDidFire = NO;

// The alert window displays instructions when the home button is held down
static NSTimer *alertTimer = nil;
static SBAlertItem *alert = nil;

static void cancelAlertTimer()
{
    // Disable and release timer (may be nil)
    [alertTimer invalidate];
    [alertTimer release];
    alertTimer = nil;
}

static void cancelAlert()
{
    // Hide and release alert window (may be nil)
    [alert dismiss];
    [alert release];
    alert = nil;
}

@protocol BackgrounderSB
- (void)bg_applicationDidFinishLaunching:(id)application;
- (void)bg_menuButtonDown:(GSEvent *)event;
- (void)bg_menuButtonUp:(GSEvent *)event;
@end

static void $SpringBoard$toggleBackgrounding(id self, SEL sel)
{
    alertTimerDidFire = YES;

    // Notify the application that the menu button was pressed
    id app = [displayStack topApplication];
    if (app)
        kill([app pid], SIGUSR1);
}

static void backgroundingToggled(CFNotificationCenterRef center, void *observer,
    CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    // Display popup alert
    NSString *status = [NSString stringWithFormat:@"Backgrounding %s",
        ([(NSString *)name isEqualToString:@NOTICE_ENABLED] ? "Enabled" : "Disabled")];
        
    Class $BackgrounderAlertItem = objc_getClass("BackgrounderAlertItem");
    alert = [[$BackgrounderAlertItem alloc] initWithTitle:status
        message:@"(Continue holding to force-quit)"];

    Class $SBAlertItemsController(objc_getClass("SBAlertItemsController"));
    SBAlertItemsController *controller = [$SBAlertItemsController sharedInstance];
    [controller activateAlertItem:alert];
}

static void $SpringBoard$applicationDidFinishLaunching$(SpringBoard<BackgrounderSB> *self, SEL sel, id application)
{
    [self bg_applicationDidFinishLaunching:application];

    // Setup handler for toggle notifications
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, &backgroundingToggled, CFSTR(NOTICE_ENABLED), NULL, 0);
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, &backgroundingToggled, CFSTR(NOTICE_DISABLED), NULL, 0);
}

static void $SpringBoard$menuButtonDown$(SpringBoard<BackgrounderSB> *self, SEL sel, GSEvent *event)
{
    // Setup toggle-delay timer
    id app = [displayStack topApplication];
    if (app && app != self)
        alertTimer = [[NSTimer scheduledTimerWithTimeInterval:0.7f
            target:self selector:@selector(showBackgrounderMessageBox)
            userInfo:nil repeats:NO] retain];

    // Begin normal 'kill if held' sequence
    [self bg_menuButtonDown:event];
}

static void $SpringBoard$menuButtonUp$(SpringBoard<BackgrounderSB> *self, SEL sel, GSEvent *event)
{
    // Stop popup alert from showing (if button-up before timeout)
    cancelAlertTimer();

    // Hide and destroy the popup alert
    cancelAlert();

    [self bg_menuButtonUp:event];
}

//______________________________________________________________________________
//______________________________________________________________________________

@protocol BackgrounderSBApp
- (BOOL)bg_isSystemApplication;
- (BOOL)bg_shouldLaunchPNGless;
- (BOOL)bg_kill;
@end

static BOOL $SBApplication$isSystemApplication(SBApplication<BackgrounderSBApp> *self, SEL sel)
{
    // Non-system applications get killed; if app is running, report as system
    // NOTE: Simply returning YES here can cause problems with SpringBoard,
    //       such as the inability to uinstall an AppStore application
    //return (self == [displayStack topApplication]) ? YES : [self bg_isSystemApplication];
    return ([self pid] != -1) ? YES : [self bg_isSystemApplication];
}

static BOOL $SBApplication$shouldLaunchPNGless(SBApplication<BackgrounderSBApp> *self, SEL sel)
{
    // Only show splash-screen on initial launch
    return ([self pid] != -1) ? YES : [self bg_shouldLaunchPNGless];
}

static BOOL $SBApplication$kill(SBApplication<BackgrounderSBApp> *self, SEL sel)
{
    // Hide and destroy the popup alert
    cancelAlert();
    return [self bg_kill];
}

// -----------------------------------------------------------------------------
// ---------------------------- THE APPLICATION --------------------------------
// -----------------------------------------------------------------------------

static BOOL backgroundingEnabled = NO;

static void toggleBackgrounding(int signal)
{
    backgroundingEnabled = !backgroundingEnabled;

    // Send notification of toggling
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (backgroundingEnabled ? CFSTR(NOTICE_ENABLED) : CFSTR(NOTICE_DISABLED)),
        NULL, NULL, true);
}

//______________________________________________________________________________
//______________________________________________________________________________

@protocol BackgrounderApp
- (void)bg_applicationWillSuspend;
- (void)bg_applicationDidResume;
- (void)bg_applicationWillResignActive:(UIApplication *)application;
- (void)bg_applicationDidBecomeActive:(UIApplication *)application;;
- (void)bg_applicationSuspend:(GSEvent *)event;
//- (void)bg__setSuspended:(BOOL)val;
- (void)bg__loadMainNibFile;
@end

// Prevent execution of application's on-suspend/resume methods
static void $UIApplication$applicationWillSuspend(UIApplication<BackgrounderApp> *self, SEL sel)
{
    if (!backgroundingEnabled)
        [self bg_applicationWillSuspend];
}

static void $UIApplication$applicationDidResume(UIApplication<BackgrounderApp> *self, SEL sel)
{
    if (!backgroundingEnabled)
        [self bg_applicationDidResume];
}

static void $UIApplication$applicationWillResignActive$(UIApplication<BackgrounderApp> *self, SEL sel, id application)
{
    if (!backgroundingEnabled)
        [self bg_applicationWillResignActive:application];
}

static void $UIApplication$applicationDidBecomeActive$(UIApplication<BackgrounderApp> *self, SEL sel, id application)
{
    if (!backgroundingEnabled)
        [self bg_applicationDidBecomeActive:application];
}

// Overriding this method prevents the application from quitting on suspend
static void $UIApplication$applicationSuspend$(UIApplication<BackgrounderApp> *self, SEL sel, GSEvent *event)
{
    if (!backgroundingEnabled)
        [self bg_applicationSuspend:event];
}

// FIXME: Tests make this appear unneeded... confirm
#if 0
static void $UIApplication$_setSuspended$(UIApplication<BackgrounderApp> *self, SEL sel, BOOL val)
{
    //[self bg__setSuspended:val];
}
#endif

static void $UIApplication$_loadMainNibFile(UIApplication<BackgrounderApp> *self, SEL sel)
{
    // NOTE: This method always gets called, even if no NIB files are used.
    //       Also note that if an application overrides this method (unlikely,
    //       but possible), this extension's hooks will not be installed.
    [self bg__loadMainNibFile];

    Class $UIApplication([self class]);
    MSHookMessage($UIApplication, @selector(applicationSuspend:), (IMP)&$UIApplication$applicationSuspend$, "bg_");
    MSHookMessage($UIApplication, @selector(applicationWillSuspend), (IMP)&$UIApplication$applicationWillSuspend, "bg_");
    MSHookMessage($UIApplication, @selector(applicationDidResume), (IMP)&$UIApplication$applicationDidResume, "bg_");

    id delegate = [self delegate];
    Class $AppDelegate(delegate ? [delegate class] : [self class]);
    MSHookMessage($AppDelegate, @selector(applicationWillResignActive:), (IMP)&$UIApplication$applicationWillResignActive$, "bg_");
    MSHookMessage($AppDelegate, @selector(applicationDidBecomeActive:), (IMP)&$UIApplication$applicationDidBecomeActive$, "bg_");
}

//______________________________________________________________________________
//______________________________________________________________________________

#define PREFS_FILE "/var/mobile/Library/Preferences/jp.ashikase.backgrounder.plist"

extern "C" void BackgrounderInitialize()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];

    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        // Is SpringBoard
        Class $SBDisplayStack(objc_getClass("SBDisplayStack"));
        MSHookMessage($SBDisplayStack, @selector(init), (IMP)&$SBDisplayStack$init, "bg_");

        Class $SpringBoard(objc_getClass("SpringBoard"));
        MSHookMessage($SpringBoard, @selector(applicationDidFinishLaunching:), (IMP)&$SpringBoard$applicationDidFinishLaunching$, "bg_");
        MSHookMessage($SpringBoard, @selector(menuButtonDown:), (IMP)&$SpringBoard$menuButtonDown$, "bg_");
        MSHookMessage($SpringBoard, @selector(menuButtonUp:), (IMP)&$SpringBoard$menuButtonUp$, "bg_");
        class_addMethod($SpringBoard, @selector(showBackgrounderMessageBox), (IMP)&$SpringBoard$toggleBackgrounding, "v@:");

        Class $SBApplication(objc_getClass("SBApplication"));
        MSHookMessage($SBApplication, @selector(isSystemApplication), (IMP)&$SBApplication$isSystemApplication, "bg_");
        MSHookMessage($SBApplication, @selector(shouldLaunchPNGless), (IMP)&$SBApplication$shouldLaunchPNGless, "bg_");
        MSHookMessage($SBApplication, @selector(kill), (IMP)&$SBApplication$kill, "bg_");

        // Create custom alert-item class
        Class $SBAlertItem(objc_getClass("SBAlertItem"));
        Class $BackgrounderAlertItem = objc_allocateClassPair($SBAlertItem, "BackgrounderAlertItem", 0);
        class_addIvar($BackgrounderAlertItem, "title", sizeof(id), 0, "@");
        class_addIvar($BackgrounderAlertItem, "message", sizeof(id), 0, "@");
        class_addMethod($BackgrounderAlertItem, @selector(initWithTitle:message:),
                (IMP)&$BackgrounderAlertItem$initWithTitle$message$, "@@:@@");
        class_addMethod($BackgrounderAlertItem, @selector(dealloc),
                (IMP)&$BackgrounderAlertItem$dealloc, "v@:");
        class_addMethod($BackgrounderAlertItem, @selector(configure:requirePasscodeForActions:),
                (IMP)&$BackgrounderAlertItem$configure$requirePasscodeForActions$, "v@:cc");
        objc_registerClassPair($BackgrounderAlertItem);
    } else {
        // Is an application
        Class $UIApplication(objc_getClass("UIApplication"));
        MSHookMessage($UIApplication, @selector(_loadMainNibFile), (IMP)&$UIApplication$_loadMainNibFile, "bg_");

        // Setup action to take upon receiving toggle signal from SpringBoard
        // NOTE: Done this way as the application hooks *must* be installed in
        //       the UIApplication process, not the SpringBoard process
        sigset_t block_mask;
        sigfillset(&block_mask);
        struct sigaction action;
        action.sa_handler = toggleBackgrounding;
        action.sa_mask = block_mask;
        action.sa_flags = 0;
        sigaction(SIGUSR1, &action, NULL);

        // Check if this application defaults to backgrounding
        // NOTE: Can't use CFPreferences* functions due to AppStore sandboxing
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@PREFS_FILE];
        NSArray *array = [prefs objectForKey:@"enabled_apps"];
        if ([array containsObject:identifier])
            backgroundingEnabled = YES;
    }

    [pool release];
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
