/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-05-12 10:40:04
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


#import "TaskMenuPopup.h"

#import "Common.h"

#import <objc/message.h>

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UINavigationBarBackground.h>
#import <UIKit/UIRemoveControlTextButton.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBUIController.h>

#import "SpringBoardHooks.h"


HOOK(UIRemoveControlTextButton, initWithRemoveControl$withTarget$withLabel$,
    id, id control, UITableViewCell *target, NSString *label)
{
    NSString *newLabel = nil;
    switch ([target tag]) {
        case 1:
            // Is blacklisted application
            newLabel = @"Force Quit";
            break;
        case 2:
            // Is SpringBoard
            newLabel = @"Respring";
            break;
        default:
            newLabel = @"Quit";
    }
    return CALL_ORIG(UIRemoveControlTextButton, initWithRemoveControl$withTarget$withLabel$,
        control, target, newLabel);
}

//______________________________________________________________________________
//______________________________________________________________________________

@interface TaskList : UIView <UITableViewDelegate, UITableViewDataSource>
{
    NSString *currentApp;
    NSMutableArray *otherApps;
}

@property(nonatomic, copy) NSString *currentApp;
@property(nonatomic, retain) NSMutableArray *otherApps;

@end

@implementation TaskList

@synthesize currentApp;
@synthesize otherApps;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        CGSize size = frame.size;

        // Get the status bar height (normally 0 (hidden) or 20 (shown))
        Class $SBStatusBarController(objc_getClass("SBStatusBarController"));
        UIWindow *statusBar = [[$SBStatusBarController sharedStatusBarController] statusBarWindow];
        float statusBarHeight = [statusBar frame].size.height;

        // Create a top navigation bar
        UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"Active Applications"];
        UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, statusBarHeight, size.width, 44)];
        [navBar setTintColor:[UIColor colorWithWhite:0.23 alpha:1]];
        [navBar pushNavigationItem:navItem];
        //[navBar showButtonsWithLeftTitle:nil rightTitle:@"Edit"];
        [navItem release];
        [self addSubview:navBar];
        [navBar release];

        // Create a table, which acts as the main body of the popup
        UITableView *table = [[UITableView alloc] initWithFrame:
            CGRectMake(0, statusBarHeight + 44, size.width, size.height - statusBarHeight - 44 - 44)
            style:0];
        [table setDataSource:self];
        [table setDelegate:self];
        [table setRowHeight:68];
        [self addSubview:table];
        [table release];

        // Create a bottom bar which contains instructional information
        Class $UINavigationBarBackground(objc_getClass("UINavigationBarBackground"));
        UINavigationBarBackground *footer = [[$UINavigationBarBackground alloc]
            initWithFrame:CGRectMake(0, size.height - 44, size.width, 44)
            withBarStyle:0
            withTintColor:[UIColor colorWithWhite:0.23 alpha:1]];
        [self addSubview:footer];
        [footer release];

        // Instructional item one
        UILabel *footerText = [[UILabel alloc] initWithFrame:CGRectMake(0, size.height - 44, size.width, 22)];
        [footerText setText:@"Tap an application to switch"];
        [footerText setTextAlignment:1];
        [footerText setTextColor:[UIColor whiteColor]];
        [footerText setBackgroundColor:[UIColor clearColor]];
        [self addSubview:footerText];
        [footerText release];

        // Instructional item two
        footerText = [[UILabel alloc] initWithFrame:CGRectMake(0, size.height - 22, size.width, 22)];
        [footerText setText:@"Tap the Home Button to cancel"];
        [footerText setTextAlignment:1];
        [footerText setTextColor:[UIColor whiteColor]];
        [footerText setBackgroundColor:[UIColor clearColor]];
        [self addSubview:footerText];
        [footerText release];
    }
    return self;
}

- (void)dealloc
{
    [currentApp release];
    [otherApps release];

    [super dealloc];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    return (section == 0) ? @"Current Application" : @"Other Applications";
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return (section == 0) ? 1 : [otherApps count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 68;
}

extern "C" UIImage * _UIImageWithName(NSString *name);

#if 0
static UIImage *imageForQuitButton()
{
    // Load the red circle image
    CGImageRef circleRef = [_UIImageWithName(@"UIRemoveControlMinus.png") CGImage];
    CGRect circleRect = CGRectMake(0, 0, CGImageGetWidth(circleRef), CGImageGetHeight(circleRef));

    // Create a new context to draw to
    CGContextRef context = CGBitmapContextCreate(NULL, circleRect.size.width, circleRect.size.height,
            CGImageGetBitsPerComponent(circleRef), 4 * circleRect.size.width, CGImageGetColorSpace(circleRef),
            CGImageGetAlphaInfo(circleRef));

    // Draw the circle
    CGContextDrawImage(context, circleRect, circleRef);

    // Load and draw the minus sign
    CGImageRef minusRef = [_UIImageWithName(@"UIRemoveControlMinusCenter.png") CGImage];
    CGRect minusRect = CGRectMake(0, 0, CGImageGetWidth(minusRef), CGImageGetHeight(minusRef));
    minusRect.origin.x = (circleRect.size.width - minusRect.size.width) / 2.0;
    // NOTE: the offset starts at the lower left
    minusRect.origin.y = 1 + (circleRect.size.height - minusRect.size.height) / 2.0;
    CGContextDrawImage(context, minusRect, minusRef);

    CGImageRef imageRef = CGBitmapContextCreateImage(context);

    UIImage *image = [UIImage imageWithCGImage:imageRef];

    CGContextRelease(context);
    CGImageRelease(imageRef);

    return image;
}
#endif

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"TaskMenuCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];
        [cell setSelectionStyle:2];
    }

    // Get the display identifier of the application for this cell
    NSString *identifier = (indexPath.section == 0) ? currentApp : [otherApps objectAtIndex:indexPath.row];

    // Get the SBApplication object
    Class $SBApplicationController(objc_getClass("SBApplicationController"));
    SBApplication *app = [[$SBApplicationController sharedInstance] applicationWithDisplayIdentifier:identifier];

    // Set the cell's text to the name of the application
    [cell setText:[app displayName]];

    // Set the cell's image to the application's icon image
    UIImage *image = nil;
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        image = [UIImage imageWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/applelogo.png"];
        image = [image _imageScaledToSize:CGSizeMake(59, 62) interpolationQuality:0];
        // Also, mark that this cell represents SpringBoard
        [cell setTag:2];
    } else {
        image = [UIImage imageWithContentsOfFile:[app pathForIcon]];
    }
    [cell setImage:image];

    // Mark whether this application is blacklisted
    if ([identifier isEqualToString:@"com.apple.mobilemail"] ||
        [identifier isEqualToString:@"com.apple.mobilephone"])
        [cell setTag:1];

#if 0
    // Add a quit button to the cell
    // NOTE: The button frame is set to be as tall as the row, and slightly
    //       wider than the button image; this is doen to provide an easy-to-hit
    //       "tap zone".
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 35, 68)];
    [button setImage:imageForQuitButton() forState:0];
    [button addTarget:tableView action:@selector(_accessoryButtonAction:) forControlEvents:64];
    [cell setAccessoryView:button];
    [button release];
#endif

    return cell;
}

- (void)tableView:(UITableView *)tableView
  commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Get the display identifier of the application for this cell
        NSString *identifier = (indexPath.section == 0) ? currentApp : [otherApps objectAtIndex:indexPath.row];

        Class $SpringBoard(objc_getClass("SpringBoard"));
        SpringBoard *springBoard = [$SpringBoard sharedApplication];
        [springBoard quitAppWithDisplayIdentifier:identifier];

        if (indexPath.section == 0) {
            [springBoard dismissBackgrounderFeedback];
        } else {
            [otherApps removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
        }
    }
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Class $SpringBoard(objc_getClass("SpringBoard"));
    SpringBoard *springBoard = [$SpringBoard sharedApplication];

    if (indexPath.section == 0) {
        [springBoard dismissBackgrounderFeedback];
    } else {
        if (![currentApp isEqualToString:@"com.apple.springboard"])
            // Enable backgrounding for current application
            [springBoard setBackgroundingEnabled:YES forDisplayIdentifier:currentApp];

        // Switch to selected application
        [springBoard switchToAppWithDisplayIdentifier:[otherApps objectAtIndex:indexPath.row]];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    // Get the display identifier of the application for this cell
    NSString *identifier = nil;
    if (indexPath.section == 0)
        identifier = currentApp;
    else
        identifier = [otherApps objectAtIndex:indexPath.row];

    Class $SpringBoard(objc_getClass("SpringBoard"));
    SpringBoard *sb = [$SpringBoard sharedApplication];
    [sb quitAppWithDisplayIdentifier:identifier];
}

@end

//______________________________________________________________________________
//______________________________________________________________________________

static id $BGAlertDisplay$initWithSize$(SBAlertDisplay *self, SEL sel, CGSize size)
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);

    Class $SBAlertDisplay = objc_getClass("SBAlertDisplay");
    objc_super $super = {self, $SBAlertDisplay};
    self = objc_msgSendSuper(&$super, @selector(initWithFrame:), rect);
    if (self) {
        [self setBackgroundColor:[UIColor colorWithWhite:0.30 alpha:1]];

        TaskList *tl = [[TaskList alloc] initWithFrame:rect];
        [self addSubview:tl];
        [tl release];

        // Set the initial position of the view as off-screen
        [self setOrigin:CGPointMake(0, size.height)];
    }
    return self;
}

static void $BGAlertDisplay$alertDisplayWillBecomeVisible(SBAlertDisplay *self, SEL sel)
{
    TaskList *tl = [[self subviews] objectAtIndex:0];
    [tl setCurrentApp:[[self alert] currentApp]];
    [tl setOtherApps:[NSMutableArray arrayWithArray:[[self alert] otherApps]]];
}

static void $BGAlertDisplay$alertDisplayBecameVisible(SBAlertDisplay *self, SEL sel)
{
    // FIXME: The proper method for animating an SBAlertDisplay is currently
    //        unknown; for now, the following method seems to work well enough
    [UIView beginAnimations:nil context:NULL];
    [self setFrame:[[UIScreen mainScreen] bounds]];
    [UIView commitAnimations];

    // NOTE: There is no need to call the superclass's method, as its
    //       implementation does nothing
}

static void $BGAlertDisplay$dismiss(SBAlertDisplay *self, SEL sel)
{
    // FIXME: The proper method for animating an SBAlertDisplay is currently
    //        unknown; for now, the following method seems to work well enough
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:
        @selector(alertDidAnimateOut:finished:context:)];
    [self setOrigin:CGPointMake(0, [self bounds].size.height)];
    [UIView commitAnimations];
}

static void $BGAlertDisplay$alertDidAnimateOut$finished$context$(SBAlertDisplay *self, SEL sel,
    NSString *animationID, NSNumber *finished, void *context)
{
    // Continue dismissal by calling super's dismiss method
    Class $SBAlertDisplay = objc_getClass("SBAlertDisplay");
    objc_super $super = {self, $SBAlertDisplay};
    objc_msgSendSuper(&$super, @selector(dismiss));
}

//______________________________________________________________________________
//______________________________________________________________________________

static id $BGAlert$initWithCurrentApp$otherApps$(SBAlert *self, SEL sel, NSString *currentApp, NSArray *otherApps)
{
    Class $SBAlert = objc_getClass("SBAlert");
    objc_super $super = {self, $SBAlert};
    self = objc_msgSendSuper(&$super, @selector(init));
    if (self) {
        object_setInstanceVariable(self, "currentApp", reinterpret_cast<void *>([currentApp retain])); 
        object_setInstanceVariable(self, "otherApps", reinterpret_cast<void *>([otherApps retain])); 
    }
    return self;
}

static void $BGAlert$dealloc(SBAlert *self, SEL sel)
{
    id currentApp = nil, otherApps = nil;
    object_getInstanceVariable(self, "currentApp", reinterpret_cast<void **>(&currentApp));
    object_getInstanceVariable(self, "otherApps", reinterpret_cast<void **>(&otherApps));
    [currentApp release];
    [otherApps release];

    Class $SBAlert = objc_getClass("SBAlert");
    objc_super $super = {self, $SBAlert};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

static NSString * $BGAlert$currentApp(SBAlert *self, SEL sel)
{
    NSString *currentApp = nil;
    object_getInstanceVariable(self, "currentApp", reinterpret_cast<void **>(&currentApp));
    return currentApp;
}

static NSArray * $BGAlert$otherApps(SBAlert *self, SEL sel)
{
    NSArray *otherApps = nil;
    object_getInstanceVariable(self, "otherApps", reinterpret_cast<void **>(&otherApps));
    return otherApps;
}

static id $BGAlert$alertDisplayViewWithSize$(SBAlert *self, SEL sel, CGSize size)
{
    Class $BGAlertDisplay = objc_getClass("BackgrounderAlertDisplay");
    return [[[$BGAlertDisplay alloc] initWithSize:size] autorelease];
}

//______________________________________________________________________________
//______________________________________________________________________________

void initTaskMenuPopup()
{
    // Override default text for cell "delete" button
    Class $UIRemoveControlTextButton(objc_getClass("UIRemoveControlTextButton"));
    _UIRemoveControlTextButton$initWithRemoveControl$withTarget$withLabel$ =
        MSHookMessage($UIRemoveControlTextButton, @selector(initWithRemoveControl:withTarget:withLabel:),
            &$UIRemoveControlTextButton$initWithRemoveControl$withTarget$withLabel$);

    // Create custom alert-display class
    Class $SBAlertDisplay(objc_getClass("SBAlertDisplay"));
    Class $BGAlertDisplay = objc_allocateClassPair($SBAlertDisplay, "BackgrounderAlertDisplay", 0);
    class_addIvar($BGAlertDisplay, "navController", sizeof(id), 0, "@");
    class_addMethod($BGAlertDisplay, @selector(initWithSize:),
            (IMP)&$BGAlertDisplay$initWithSize$, "@@:{CGSize=ff}");
    class_addMethod($BGAlertDisplay, @selector(alertDisplayWillBecomeVisible),
            (IMP)&$BGAlertDisplay$alertDisplayWillBecomeVisible, "v@:");
    class_addMethod($BGAlertDisplay, @selector(alertDisplayBecameVisible),
            (IMP)&$BGAlertDisplay$alertDisplayBecameVisible, "v@:");
    class_addMethod($BGAlertDisplay, @selector(dismiss),
            (IMP)&$BGAlertDisplay$dismiss, "v@:");
    class_addMethod($BGAlertDisplay, @selector(alertDidAnimateOut:finished:context:),
            (IMP)&$BGAlertDisplay$alertDidAnimateOut$finished$context$, "v@:@@^v");
    objc_registerClassPair($BGAlertDisplay);

    // Create custom alert class
    Class $SBAlert(objc_getClass("SBAlert"));
    Class $BGAlert = objc_allocateClassPair($SBAlert, "BackgrounderAlert", 0);
    class_addIvar($BGAlert, "currentApp", sizeof(id), 0, "@");
    class_addIvar($BGAlert, "otherApps", sizeof(id), 0, "@");
    class_addMethod($BGAlert, @selector(initWithCurrentApp:otherApps:),
            (IMP)&$BGAlert$initWithCurrentApp$otherApps$, "@@:@@");
    class_addMethod($BGAlert, @selector(dealloc),
            (IMP)&$BGAlert$dealloc, "v@:");
    class_addMethod($BGAlert, @selector(currentApp),
            (IMP)&$BGAlert$currentApp, "@@:");
    class_addMethod($BGAlert, @selector(otherApps),
            (IMP)&$BGAlert$otherApps, "@@:");
    class_addMethod($BGAlert, @selector(alertDisplayViewWithSize:),
            (IMP)&$BGAlert$alertDisplayViewWithSize$, "@@:{CGSize=ff}");
    objc_registerClassPair($BGAlert);
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
