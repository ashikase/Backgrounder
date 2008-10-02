/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-09-25 11:04:08
 *
 * Description:
 * ------------
 *   This is an extension to SpringBoard that allows for applications
 *   to run in the background (instead of terminating).
 *
 * Features:
 * ---------
 *   List of applicable apps.. plist..
 *
 * Limitations:
 * ------------
 *
 * Usage:
 * ------
 *
 * Todo:
 * -----
 * - add a method for proper termination of a background-enabled app.
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

#include <substrate.h>

#import <GraphicsServices/GraphicsServices.h>

#import <Foundation/NSBundle.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>

#import <SpringBoard/SBApplication.h>
#import <UIKit/UIApplication.h>


@protocol BackgrounderSB
- (BOOL)bg_isSystemApplication;
@end

static BOOL $SBApplication$isSystemApplication(UIApplication<BackgrounderSB> *self, SEL sel)
{
    // Non-system applications get killed
    return YES;
}

//______________________________________________________________________________
//______________________________________________________________________________

@protocol BackgrounderApp
- (void)bg_applicationWillSuspend;
- (void)bg_applicationWillResume;
- (void)bg_applicationWillResignActive:(UIApplication *)application;
- (void)bg_applicationDidBecomeActive:(UIApplication *)application;;
- (void)bg_applicationSuspend:(GSEvent *)event;
//- (void)bg__setSuspended:(BOOL)val;
@end

// Prevent execution of application's on-suspend/resume methods
static void $UIApplication$applicationWillSuspend(id self, SEL sel) {}
static void $UIApplication$applicationDidResume(id self, SEL sel) {}
static void $UIApplication$applicationWillResignActive$(id self, SEL sel, id application) {}
static void $UIApplication$applicationDidBecomeActive$(id self, SEL sel, id application) {}

// Overriding this method prevents the application from quitting on suspend
static void $UIApplication$applicationSuspend$(UIApplication<BackgrounderApp> *self, SEL sel, GSEvent *event)
{
    static BOOL isFirstCall = YES;

    if (isFirstCall) {
        NSLog(@"Backgrounder: hooking susps");
        Class $AppDelegate([[self delegate] class]);
        MSHookMessage($AppDelegate, @selector(applicationWillResignActive:), (IMP)&$UIApplication$applicationWillResignActive$, "bg_");
        MSHookMessage($AppDelegate, @selector(applicationDidBecomeActive:), (IMP)&$UIApplication$applicationDidBecomeActive$, "bg_");
        isFirstCall = NO;
    } else {
        NSLog(@"Backgrounder: not first call");
    }
}

#if 0
// FIXME: Tests make this appear unneeded... confirm
static void $UIApplication$_setSuspended$(UIApplication<BackgrounderApp> *self, SEL sel, BOOL val)
{
    //[self bg__setSuspended:val];
}
#endif

//______________________________________________________________________________
//______________________________________________________________________________

extern "C" void BackgrounderInitialize()
{
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"Backgrounder: bundle is: %@", identifier);

    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        Class $SBApplication(objc_getClass("SBApplication"));
        MSHookMessage($SBApplication, @selector(isSystemApplication), (IMP)&$SBApplication$isSystemApplication, "bg_");
    } else {
        // TODO: Read in plist with array containing names of apps to background
        // if ([array contains:identifier]) {
    
        
        if ([identifier isEqualToString:@"de.derflash.rooms"]) {
            NSLog(@"Backgrounder: It's Rooms");
            Class $UIApplication(objc_getClass("UIApplication"));
            MSHookMessage($UIApplication, @selector(applicationSuspend:), (IMP)&$UIApplication$applicationSuspend$, "bg_");
            //        MSHookMessage($UIApplication, @selector(_setSuspended:), (IMP)&$UIApplication$_setSuspended$, "bg_");
            MSHookMessage($UIApplication, @selector(applicationWillSuspend), (IMP)&$UIApplication$applicationWillSuspend, "bg_");
            MSHookMessage($UIApplication, @selector(applicationDidResume), (IMP)&$UIApplication$applicationDidResume, "bg_");
        }
    }
}
