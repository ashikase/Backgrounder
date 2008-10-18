/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-18 12:50:28
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

#import <objc/message.h>
#include <signal.h>
#include <substrate.h>

#import <CoreGraphics/CGAffineTransform.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBUIController.h>

#import <UIKit/NSIndexPath-UITableView.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
typedef struct {
    float top;
    float left;
    float bottom;
    float right;
} CDAnonymousStruct2;
#import <UIKit/UIImage.h>
#import <UIKit/UIImage-UIImageInternal.h>
#import <UIKit/UILabel.h>
#import <UIKit/UINavigationBar.h>
#import <UIKit/UINavigationBarBackground.h>
#import <UIKit/UINavigationItem.h>
#import <UIKit/UIScreen.h>
@protocol UITableViewDataSource;
#import <UIKit/UITableView.h>
#import <UIKit/UITableViewCell.h>
#import <UIKit/UIView-Animation.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>

#import "SpringBoardHooks.h"


static id $BGAlertDisplay$initWithSize$(SBAlertDisplay *self, SEL sel, CGSize size)
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);

    Class $SBAlertDisplay = objc_getClass("SBAlertDisplay");
    objc_super $super = {self, $SBAlertDisplay};
    self = objc_msgSendSuper(&$super, @selector(initWithFrame:), rect);
    if (self) {
        [self setBackgroundColor:[UIColor colorWithWhite:0.30 alpha:1]];

        // Get the status bar height (normally 0 (hidden) or 20 (shown))
        Class $SBStatusBarController(objc_getClass("SBStatusBarController"));
        UIWindow *statusBar = [[$SBStatusBarController sharedStatusBarController] statusBarWindow];
        float statusBarHeight = [statusBar frame].size.height;

        // Create a top navigation bar
        UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"Active Applications"];
        UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, statusBarHeight, size.width, 44)];
        [navBar setTintColor:[UIColor colorWithWhite:0.23 alpha:1]];
        [navBar pushNavigationItem:navItem];
        [navBar showButtonsWithLeftTitle:nil rightTitle:@"Edit"];
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

        // Set the initial position of the view as off-screen
        [self setOrigin:CGPointMake(0, size.height)];
    }
    return self;
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

#pragma mark - UITableViewDataSource

static int $BGAlertDisplay$numberOfSectionsInTableView$(id self, SEL sel, UITableView *tableView)
{
    // Two sections: "current" and "other" applications
	return 2;
}

static NSString * $BGAlertDisplay$tableView$titleForHeaderInSection$(id self, SEL sel, UITableView *tableView, int section)
{
    return (section == 0) ? @"Current Application" : @"Other Applications";
}

static int $BGAlertDisplay$tableView$numberOfRowsInSection$(id self, SEL sel, UITableView *tableView, int section)
{
    return (section == 0) ? 1 : [[[self alert] otherApps] count];
}


static UITableViewCell * $BGAlertDisplay$tableView$cellForRowAtIndexPath$(id self, SEL sel, UITableView *tableView, NSIndexPath *indexPath)
{
    static NSString *reuseIdentifier = @"TaskMenuCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil)
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];
    [cell setSelectionStyle:2];

    // Get the display identifier of the application for this cell
    NSString *identifier = nil;
    if (indexPath.section == 0) {
        identifier = [[self alert] currentApp];
    } else {
        identifier = [[[self alert] otherApps] objectAtIndex:indexPath.row];
    }

    // Get the SBApplication object
    Class $SBApplicationController(objc_getClass("SBApplicationController"));
    SBApplication *app = [[$SBApplicationController sharedInstance] applicationWithDisplayIdentifier:identifier];

    // Set the cell text and image
    [cell setText:[app displayName]];
    UIImage *icon = nil;
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        icon = [UIImage imageWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/applelogo.png"];
        icon = [icon _imageScaledToSize:CGSizeMake(59, 62) interpolationQuality:0];
    } else {
        icon = [UIImage imageWithContentsOfFile:[app pathForIcon]];
    }
    [cell setImage:icon];

    return cell;
}

#pragma mark - UITableViewCellDelegate

static void $BGAlertDisplay$tableView$didSelectRowAtIndexPath$(id self, SEL sel, UITableView *tableView, NSIndexPath *indexPath)
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1) {
        // Selected a row under "Other applications"

        // Enable backgrounding for current application
        Class $SpringBoard(objc_getClass("SpringBoard"));
        SpringBoard *springBoard = [$SpringBoard sharedApplication];
        [springBoard setBackgroundingEnabled:YES forDisplayIdentifier:[[self alert] currentApp]];

        // Switch to selected application
        Class $SBUIController(objc_getClass("SBUIController"));
        SBUIController *uiCont = [$SBUIController sharedInstance];
        if (indexPath.row == 0) {
            // SpringBoard was selected
            [uiCont quitTopApplication];
        } else {
            NSArray *otherApps = [[self alert] otherApps];
            Class $SpringBoard(objc_getClass("SpringBoard"));
            SpringBoard *sb = [$SpringBoard sharedApplication];
            NSLog(@"Backgrounder: asking to swtich to: %@", [otherApps objectAtIndex:indexPath.row]);
            [sb switchToAppWithDisplayIdentifier:[otherApps objectAtIndex:indexPath.row]];
        }
    }
}

//______________________________________________________________________________
//______________________________________________________________________________

static id $BGAlert$initWithCurrentApp$otherApps$(SBAlert *self, SEL sel, SBApplication *currentApp, NSArray *otherApps)
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
    NSLog(@"Backgrounder: DEALLOC CALLED FOR ALERT");
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
    // Create custom alert-display class
    Class $SBAlertDisplay(objc_getClass("SBAlertDisplay"));
    Class $BGAlertDisplay = objc_allocateClassPair($SBAlertDisplay, "BackgrounderAlertDisplay", 0);
    class_addMethod($BGAlertDisplay, @selector(initWithSize:),
            (IMP)&$BGAlertDisplay$initWithSize$, "@@:{CGSize=ff}");
    class_addMethod($BGAlertDisplay, @selector(alertDisplayBecameVisible),
            (IMP)&$BGAlertDisplay$alertDisplayBecameVisible, "v@:");
    // UITable-releated methods
    class_addMethod($BGAlertDisplay, @selector(numberOfSectionsInTableView:),
            (IMP)&$BGAlertDisplay$numberOfSectionsInTableView$, "i@:@");
    class_addMethod($BGAlertDisplay, @selector(tableView:titleForHeaderInSection:),
            (IMP)&$BGAlertDisplay$tableView$titleForHeaderInSection$, "@@:@i");
    class_addMethod($BGAlertDisplay, @selector(tableView:numberOfRowsInSection:),
            (IMP)&$BGAlertDisplay$tableView$numberOfRowsInSection$, "i@:@i");
    class_addMethod($BGAlertDisplay, @selector(tableView:cellForRowAtIndexPath:),
            (IMP)&$BGAlertDisplay$tableView$cellForRowAtIndexPath$, "@@:@@");
    class_addMethod($BGAlertDisplay, @selector(tableView:didSelectRowAtIndexPath:),
            (IMP)&$BGAlertDisplay$tableView$didSelectRowAtIndexPath$, "v@:@@");
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
            (IMP)&$BGAlert$alertDisplayViewWithSize$, "v@:{CGSize=ff}");
    objc_registerClassPair($BGAlert);
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
