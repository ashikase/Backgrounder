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

extern "C" void TweakInitialize()
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
