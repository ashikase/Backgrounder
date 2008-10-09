/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-09 21:26:24
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

#import <Foundation/NSRange.h>
#import <Foundation/NSString.h>

#import <SpringBoard/SBApplication.h>

#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIImage.h>
#import <UIKit/UILabel.h>
typedef struct {} CDAnonymousStruct2;
@protocol UITableViewDataSource;
#import <UIKit/UITableView.h>
typedef struct {
    struct CGRect left;
    struct CGRect middle;
    struct CGRect right;
} CDAnonymousStruct10;
#import <UIKit/UIThreePartButton.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>

#define IMG_PATH "/System/Library/PrivateFrameworks/TelephonyUI.framework/"


static id $BackgrounderAlertDisplay$initWithSize$application$(id self, SEL sel, CGSize size, SBApplication *application)
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);

    Class $SBAlertDisplay = objc_getClass("SBAlertDisplay");
    objc_super $super = {self, $SBAlertDisplay};
    self = objc_msgSendSuper(&$super, @selector(initWithFrame:), rect);
    if (self) {
        object_setInstanceVariable(self, "application", reinterpret_cast<void *>([application retain])); 

        // create the view here
        [self setBackgroundColor:[UIColor blackColor]];

        UIFont *font = [UIFont boldSystemFontOfSize:20.0f];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, size.width, 44)];
        [label setText:@"Active Applications"];
        [label setTextAlignment:1];
        [label setTextColor:[UIColor whiteColor]];
        [label setBackgroundColor:[UIColor blackColor]];
        [label setFont:font];
        //[label setAdjustsFontSizeToFitWidth:YES];
        [self addSubview:label];
        [label release];

#if 0
        Class $SBIconList = objc_getClass("SBIconList");
        SBIconList *iconList = [[$SBIconList alloc] initWithFrame:
            CGRectMake(0, 60, size.width, size.height - 140)];
        [self addSubview:iconList];

#endif

        UITableView *table = [[UITableView alloc] initWithFrame:
            CGRectMake(0, 0, size.width, size.height - 20 - 44 - 150 - 10)
            style:0];
        UIScrollView *scroller = [[UIScrollView alloc] initWithFrame:
            CGRectMake(0, 20 + 44, size.width, size.height - 20 - 44 - 150 - 10)];
        [scroller addSubview:table];
        [table release];

        [self addSubview:scroller];
        [scroller release];
        

        CDAnonymousStruct10 slices;
        slices.left.origin.x = 0;
        slices.left.origin.y = 0;
        slices.left.size.width = 14;
        slices.left.size.height = 47;
        slices.middle.origin.x = 15;
        slices.middle.origin.y = 0;
        slices.middle.size.width = 1;
        slices.middle.size.height = 47;
        slices.right.origin.x = 16;
        slices.right.origin.y = 0;
        slices.right.size.width = 14;
        slices.right.size.height = 47;

        UIImage *normal = [UIImage imageWithContentsOfFile:@IMG_PATH"bottombardarkgray.png"];
        UIImage *pressed = [UIImage imageWithContentsOfFile:@IMG_PATH"bottombardarkgray_pressed.png"];

        SBApplication *application = nil;
        object_getInstanceVariable(self, "application", reinterpret_cast<void **>(&application));
        NSString *appName = [application displayName];

        UIThreePartButton *pButton = [[UIThreePartButton alloc] initWithTitle:[NSString stringWithFormat:@"Minimize %@", appName]];
        [pButton setTitleFont:font];
        [pButton setBackgroundImage:normal];
        [pButton setPressedBackgroundImage:pressed];
        [pButton setBackgroundSlices:slices];
        [pButton setFrame:CGRectMake(20, size.height - 150, size.width - 40, 47)];
        [self addSubview:pButton];
        [pButton release];

        pButton = [[UIThreePartButton alloc] initWithTitle:[NSString stringWithFormat:@"Quit %@", appName]];
        [pButton setTitleFont:font];
        [pButton setBackgroundImage:normal];
        [pButton setPressedBackgroundImage:pressed];
        [pButton setBackgroundSlices:slices];
        [pButton setFrame:CGRectMake(20, size.height - 100, size.width - 40, 47)];
        [self addSubview:pButton];
        [pButton release];

        normal = [UIImage imageWithContentsOfFile:@IMG_PATH"bottombarredfire.png"];
        pressed = [UIImage imageWithContentsOfFile:@IMG_PATH"bottombarredfire_pressed.png"];

        pButton = [[UIThreePartButton alloc] initWithTitle:@"Cancel" autosizesToFit:YES];
        [pButton setTitleFont:font];
        [pButton setBackgroundImage:normal];
        [pButton setPressedBackgroundImage:pressed];
        [pButton setBackgroundSlices:slices];
        [pButton setFrame:CGRectMake(20, size.height - 50, size.width - 40, 47)];
        [self addSubview:pButton];
        [pButton release];

        [self setShouldAnimateIn:YES];
    }
    return self;
}

static void $BackgrounderAlertDisplay$dealloc(id self, SEL sel)
{
    SBApplication *application = nil;
    object_getInstanceVariable(self, "application", reinterpret_cast<void **>(&application));
    [application release];

    Class $SBAlertDisplay = objc_getClass("SBAlertDisplay");
    objc_super $super = {self, $SBAlertDisplay};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

//______________________________________________________________________________
//______________________________________________________________________________

static id $BackgrounderAlert$initWithApplication$(id self, SEL sel, SBApplication *application)
{
    Class $SBAlert = objc_getClass("SBAlert");
    objc_super $super = {self, $SBAlert};
    self = objc_msgSendSuper(&$super, @selector(init));
    if (self) {
        object_setInstanceVariable(self, "application", reinterpret_cast<void *>([application retain])); 
    }
    return self;
}

static void $BackgrounderAlert$dealloc(id self, SEL sel)
{
    SBApplication *application = nil;
    object_getInstanceVariable(self, "application", reinterpret_cast<void **>(&application));
    [application release];

    Class $SBAlert = objc_getClass("SBAlert");
    objc_super $super = {self, $SBAlert};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

static id $BackgrounderAlert$alertDisplayViewWithSize$(id self, SEL sel, CGSize size)
{
    SBApplication *application = nil;
    object_getInstanceVariable(self, "application", reinterpret_cast<void **>(&application));

    Class $BackgrounderAlertDisplay = objc_getClass("BackgrounderAlertDisplay");
    id myAlert = [[[$BackgrounderAlertDisplay alloc] initWithSize:size application:application] autorelease];
    return myAlert;
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
