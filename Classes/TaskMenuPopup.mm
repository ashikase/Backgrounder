/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-06-24 14:20:00
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
#import <QuartzCore/CALayer.h>
#import <UIKit/UIKit.h>
#import <UIKit/UINavigationBarBackground.h>
#import <UIKit/UIRemoveControlTextButton.h>

#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconBadge.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBStatusBarController.h>

#import "SpringBoardHooks.h"

@interface UINavigationBarBackground (ThreeO)
- (id)initWithFrame:(CGRect)frame withBarStyle:(int)style withTintColor:(UIColor *)color isTranslucent:(BOOL)translucent;
@end

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

#import "../../DebugUIKit.h"

@interface TaskListCell : UITableViewCell
{
    UIImage *badge;
    UIImageView *badgeView;
}

@property(nonatomic, retain) UIImage *badge;

@end

@implementation TaskListCell

@synthesize badge;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier];
    if (self) {
        badgeView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:badgeView];
    }
    return self;
}

- (void)dealloc
{
    [badge release];
    [badgeView release];

    [super dealloc];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (badge) {
        // Determine position of upper-right corner of icon image
        UIImageView *imageView = MSHookIvar<UIImageView *>(self, "_imageView");
        CGRect imageRect = [imageView frame];
        CGPoint corner = CGPointMake(imageRect.origin.x + imageRect.size.width - 1, imageRect.origin.y);

        [badgeView setImage:badge];
        [badgeView setOrigin:CGPointMake(corner.x - badge.size.width + 11.0f, corner.y - 8.0f)];
        [self.contentView bringSubviewToFront:badgeView];
    }
}

@end

//______________________________________________________________________________
//______________________________________________________________________________

@interface TaskList : UIView <UITableViewDelegate, UITableViewDataSource>
{
    NSString *currentApp;
    NSMutableArray *otherApps;
    NSArray *blacklistedApps;
}

@property(nonatomic, copy) NSString *currentApp;
@property(nonatomic, retain) NSMutableArray *otherApps;
@property(nonatomic, retain) NSArray *blacklistedApps;

@end

@implementation TaskList

@synthesize currentApp;
@synthesize otherApps;
@synthesize blacklistedApps;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        CGSize size = frame.size;
        const float statusBarHeight = 20.0f;

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
        UINavigationBarBackground *footer = [[objc_getClass("UINavigationBarBackground") alloc]
            initWithFrame:CGRectMake(0, size.height - 44, size.width, 44)
            withBarStyle:0
            withTintColor:[UIColor colorWithWhite:0.23 alpha:1]
            isTranslucent:NO];
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
    [blacklistedApps release];

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

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = (indexPath.section == 0) ? currentApp : [otherApps objectAtIndex:indexPath.row];
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
    SBIconBadge *badge = MSHookIvar<SBIconBadge *>(icon, "_badge");
    return (badge ? 76.0f : 68.0f);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"TaskMenuCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    TaskListCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[TaskListCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];
        [cell setSelectionStyle:2];
    }

    // Get the display identifier of the application for this cell
    NSString *identifier = (indexPath.section == 0) ? currentApp : [otherApps objectAtIndex:indexPath.row];

    // Get the application icon object
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];

    // Set the cell's text to the name of the application
    [cell setText:[icon displayName]];

    // Set the cell's image to the application's icon image
    UIImage *image = nil;
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        // Is SpringBoard
        image = [UIImage imageWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/applelogo.png"];
        image = [image _imageScaledToSize:CGSizeMake(59, 60) interpolationQuality:0];
        // Take opportunity to mark that this cell represents SpringBoard
        [cell setTag:2];
    } else {
        // Is an application
        image = [icon icon];

        SBIconBadge *badge = MSHookIvar<SBIconBadge *>(icon, "_badge");
        if (badge) {
            UIGraphicsBeginImageContext([badge frame].size);
            [[badge layer] renderInContext:UIGraphicsGetCurrentContext()];
            [cell setBadge:UIGraphicsGetImageFromCurrentImageContext()];
            UIGraphicsEndImageContext();
        }
    }
    [cell setImage:image];

    // Mark whether this application is blacklisted
    if ([blacklistedApps containsObject:identifier])
        [cell setTag:1];

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
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SpringBoard *springBoard = [objc_getClass("SpringBoard") sharedApplication];

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

@end

//______________________________________________________________________________
//______________________________________________________________________________

static id $BGAlertDisplay$initWithSize$(SBAlertDisplay *self, SEL sel, CGSize size)
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);

    objc_super $super = {self, objc_getClass("SBAlertDisplay")};
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
    [tl setBlacklistedApps:[[self alert] blacklistedApps]];
}

static void $BGAlertDisplay$alertDisplayBecameVisible(SBAlertDisplay *self, SEL sel)
{
    // Task list displays a black status bar; save current status-bar settings
    SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
    int &currentStatusBarMode = MSHookIvar<int>(self, "currentStatusBarMode");
    int &currentStatusBarOrientation = MSHookIvar<int>(self, "currentStatusBarOrientation");
    currentStatusBarMode = [sbCont statusBarMode];
    if (currentStatusBarMode != 2) {
        currentStatusBarOrientation = [sbCont statusBarOrientation];
        [sbCont setStatusBarMode:2 orientation:0 duration:0.4f animation:0];
    }

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
    int &currentStatusBarMode = MSHookIvar<int>(self, "currentStatusBarMode");
    if (currentStatusBarMode != 2) {
        // Restore the previous status-bar mode
        int &currentStatusBarOrientation = MSHookIvar<int>(self, "currentStatusBarOrientation");
        SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
        [sbCont setStatusBarMode:currentStatusBarMode orientation:currentStatusBarOrientation
            duration:0.4f animation:0];
    }

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
    objc_super $super = {self, objc_getClass("SBAlertDisplay")};
    objc_msgSendSuper(&$super, @selector(dismiss));
}

//______________________________________________________________________________
//______________________________________________________________________________

static id $BGAlert$initWithCurrentApp$otherApps$blacklistedApps$(SBAlert *self, SEL sel, NSString *currentApp, NSArray *otherApps, NSArray *blacklistedApps)
{
    objc_super $super = {self, objc_getClass("SBAlert")};
    self = objc_msgSendSuper(&$super, @selector(init));
    if (self) {
        object_setInstanceVariable(self, "currentApp", reinterpret_cast<void *>([currentApp retain])); 
        object_setInstanceVariable(self, "otherApps", reinterpret_cast<void *>([otherApps retain])); 
        object_setInstanceVariable(self, "blacklistedApps", reinterpret_cast<void *>([blacklistedApps retain])); 
    }
    return self;
}

static void $BGAlert$dealloc(SBAlert *self, SEL sel)
{
    id currentApp = nil, otherApps = nil, blacklistedApps = nil;
    object_getInstanceVariable(self, "currentApp", reinterpret_cast<void **>(&currentApp));
    object_getInstanceVariable(self, "otherApps", reinterpret_cast<void **>(&otherApps));
    object_getInstanceVariable(self, "blacklistedApps", reinterpret_cast<void **>(&blacklistedApps));
    [currentApp release];
    [otherApps release];
    [blacklistedApps release];

    objc_super $super = {self, objc_getClass("SBAlert")};
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

static NSArray * $BGAlert$blacklistedApps(SBAlert *self, SEL sel)
{
    NSArray *blacklistedApps = nil;
    object_getInstanceVariable(self, "blacklistedApps", reinterpret_cast<void **>(&blacklistedApps));
    return blacklistedApps;
}

static id $BGAlert$alertDisplayViewWithSize$(SBAlert *self, SEL sel, CGSize size)
{
    return [[[objc_getClass("BackgrounderAlertDisplay") alloc] initWithSize:size] autorelease];
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
    unsigned int size, align;
    NSGetSizeAndAlignment("i", &size, &align);
    class_addIvar($BGAlertDisplay, "currentStatusBarMode", size, align, "i");
    class_addIvar($BGAlertDisplay, "currentStatusBarOrientation", size, align, "i");
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
    NSGetSizeAndAlignment("@", &size, &align);
    class_addIvar($BGAlert, "currentApp", size, align, "@");
    class_addIvar($BGAlert, "otherApps", size, align, "@");
    class_addIvar($BGAlert, "blacklistedApps", size, align, "@");
    class_addMethod($BGAlert, @selector(initWithCurrentApp:otherApps:blacklistedApps:),
            (IMP)&$BGAlert$initWithCurrentApp$otherApps$blacklistedApps$, "@@:@@@");
    class_addMethod($BGAlert, @selector(dealloc),
            (IMP)&$BGAlert$dealloc, "v@:");
    class_addMethod($BGAlert, @selector(currentApp),
            (IMP)&$BGAlert$currentApp, "@@:");
    class_addMethod($BGAlert, @selector(otherApps),
            (IMP)&$BGAlert$otherApps, "@@:");
    class_addMethod($BGAlert, @selector(blacklistedApps),
            (IMP)&$BGAlert$blacklistedApps, "@@:");
    class_addMethod($BGAlert, @selector(alertDisplayViewWithSize:),
            (IMP)&$BGAlert$alertDisplayViewWithSize$, "@@:{CGSize=ff}");
    objc_registerClassPair($BGAlert);
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
