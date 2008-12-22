/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-12-22 21:58:52
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

#import "Application.h"

#include <notify.h>

#import <CoreGraphics/CGGeometry.h>
#import <Foundation/NSRunLoop.h>

#import <UIKit/UIKit.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIWindow.h>

#import "PreferencesController.h"
#import "Preferences.h"

@implementation SpringJumpsApplication

@synthesize window;

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    // Create our controller
    prefsController = [[PreferencesController alloc] init];

    // Create and show the application window
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]]; 
    [window addSubview:[prefsController view]];
    [window makeKeyAndVisible];
}

- (void)dealloc
{
    [prefsController release];
    [window release];

    [super dealloc];
}

- (void)applicationWillSuspend
{
    Preferences *prefs = [Preferences sharedInstance];
    if ([prefs isModified]) {
        // Write preferences to disk
        [prefs writeUserDefaults];

        // Respring SpringBoard
        notify_post("com.apple.language.changed");
    }
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
