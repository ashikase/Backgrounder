/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-11 17:48:10
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
#include <substrate.h>

#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGAffineTransform.h>

#import <Foundation/NSRange.h>
#import <Foundation/NSString.h>

#import <SpringBoard/SBApplication.h>

#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
typedef struct {
    float top;
    float left;
    float bottom;
    float right;
} CDAnonymousStruct2;
#import <UIKit/UIGlassButton.h>
#import <UIKit/UILabel.h>
#import <UIKit/UINavigationBar.h>
#import <UIKit/UINavigationItem.h>
@protocol UITableViewDataSource;
#import <UIKit/UITableView.h>
#import <UIKit/UIView-Animation.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>


static id $BackgrounderAlertDisplay$initWithSize$application$(SBAlertDisplay *self, SEL sel, CGSize size, SBApplication *application)
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);

    Class $SBAlertDisplay = objc_getClass("SBAlertDisplay");
    objc_super $super = {self, $SBAlertDisplay};
    self = objc_msgSendSuper(&$super, @selector(initWithFrame:), rect);
    if (self) {
        object_setInstanceVariable(self, "application", reinterpret_cast<void *>([application retain])); 

        [self setBackgroundColor:[UIColor colorWithWhite:0.30 alpha:1]];

        UIFont *font = [UIFont boldSystemFontOfSize:20.0f];

        UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"Active Applications"];
        UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 20, size.width, 44)];
        [navBar setTintColor:[UIColor colorWithWhite:0.23 alpha:1]];
        [navBar pushNavigationItem:navItem];
        [navBar showButtonsWithLeftTitle:nil rightTitle:@"Edit"];
        [navItem release];
        [self addSubview:navBar];
        [navBar release];

        // FIXME: Should determine statusbar height programatically, as it may
        //        be hidden
        UITableView *table = [[UITableView alloc] initWithFrame:
            CGRectMake(0, 20 + 44, size.width, size.height - 20 - 44 - 50 - 10)
            style:0];
        [self addSubview:table];
        [table release];

        SBApplication *application = nil;
        object_getInstanceVariable(self, "application", reinterpret_cast<void **>(&application));
        NSString *appName = [application displayName];

        CDAnonymousStruct2 insets;
        insets.top = 0;
        insets.bottom = 0;
        insets.left = 14;
        insets.right = 14;

        Class $UIGlassButton(objc_getClass("UIGlassButton"));
        UIGlassButton *gButton = [[$UIGlassButton alloc] initWithFrame:CGRectMake(20, size.height - 50, size.width - 40, 47)];
        [gButton setTitle:[NSString stringWithFormat:@"Quit %@", appName] forState:0];
        [gButton setFont:font];
        [gButton setTintColor:[UIColor colorWithRed:0.80 green:0.12 blue:0.09 alpha:1]];
        [gButton setContentEdgeInsets:insets];
        [self addSubview:gButton];
        [gButton release];
    }
    return self;
}

static void $BackgrounderAlertDisplay$dealloc(SBAlertDisplay *self, SEL sel)
{
    SBApplication *application = nil;
    object_getInstanceVariable(self, "application", reinterpret_cast<void **>(&application));
    [application release];

    Class $SBAlertDisplay = objc_getClass("SBAlertDisplay");
    objc_super $super = {self, $SBAlertDisplay};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

static void $BackgrounderAlertDisplay$alertDisplayBecameVisible(SBAlertDisplay *self, SEL sel)
{
    // FIXME: The proper method for animating an SBAlertDisplay is currently
    //        unknown; for now, the following method seems to work well enough
    [self setAlpha:0];
    [self setTransform:CGAffineTransformMakeScale(2.0, 2.0)];

    [UIView beginAnimations:nil];
    [UIView setAnimationCurve:2];
    [UIView setAnimationDuration:0.5f];
    [self setAlpha:1];
    [self setTransform:CGAffineTransformIdentity];
    [UIView commitAnimations];

    // NOTE: There is no need to call the superclass's method, as its
    //       implementation does nothing
}

//______________________________________________________________________________
//______________________________________________________________________________

static id $BackgrounderAlert$initWithApplication$(SBAlert *self, SEL sel, SBApplication *application)
{
    Class $SBAlert = objc_getClass("SBAlert");
    objc_super $super = {self, $SBAlert};
    self = objc_msgSendSuper(&$super, @selector(init));
    if (self) {
        object_setInstanceVariable(self, "application", reinterpret_cast<void *>([application retain])); 
    }
    return self;
}

static void $BackgrounderAlert$dealloc(SBAlert *self, SEL sel)
{
    SBApplication *application = nil;
    object_getInstanceVariable(self, "application", reinterpret_cast<void **>(&application));
    [application release];

    Class $SBAlert = objc_getClass("SBAlert");
    objc_super $super = {self, $SBAlert};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

static id $BackgrounderAlert$alertDisplayViewWithSize$(SBAlert *self, SEL sel, CGSize size)
{
    SBApplication *application = nil;
    object_getInstanceVariable(self, "application", reinterpret_cast<void **>(&application));

    Class $BackgrounderAlertDisplay = objc_getClass("BackgrounderAlertDisplay");
    return [[[$BackgrounderAlertDisplay alloc] initWithSize:size application:application] autorelease];
}

//______________________________________________________________________________
//______________________________________________________________________________

void initTaskMenuPopup()
{
    // Create custom alert-display class
    Class $SBAlertDisplay(objc_getClass("SBAlertDisplay"));
    Class $BackgrounderAlertDisplay = objc_allocateClassPair($SBAlertDisplay, "BackgrounderAlertDisplay", 0);
    class_addIvar($BackgrounderAlertDisplay, "application", sizeof(id), 0, "@");
    class_addMethod($BackgrounderAlertDisplay, @selector(initWithSize:application:),
            (IMP)&$BackgrounderAlertDisplay$initWithSize$application$, "@@:{CGSize=ff}@");
    class_addMethod($BackgrounderAlertDisplay, @selector(dealloc),
            (IMP)&$BackgrounderAlertDisplay$dealloc, "v@:");
    class_addMethod($BackgrounderAlertDisplay, @selector(alertDisplayBecameVisible),
            (IMP)&$BackgrounderAlertDisplay$alertDisplayBecameVisible, "v@:");
    objc_registerClassPair($BackgrounderAlertDisplay);

    // Create custom alert class
    Class $SBAlert(objc_getClass("SBAlert"));
    Class $BackgrounderAlert = objc_allocateClassPair($SBAlert, "BackgrounderAlert", 0);
    class_addIvar($BackgrounderAlert, "application", sizeof(id), 0, "@");
    class_addMethod($BackgrounderAlert, @selector(initWithApplication:),
            (IMP)&$BackgrounderAlert$initWithApplication$, "@@:@");
    class_addMethod($BackgrounderAlert, @selector(dealloc),
            (IMP)&$BackgrounderAlert$dealloc, "v@:");
    class_addMethod($BackgrounderAlert, @selector(alertDisplayViewWithSize:),
            (IMP)&$BackgrounderAlert$alertDisplayViewWithSize$, "v@:{CGSize=ff}");
    objc_registerClassPair($BackgrounderAlert);
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
