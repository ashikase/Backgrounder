/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-08-26 00:49:21
 */

/**
 * Copyright (C) 2008-2009  Lance Fetters (aka. ashikase)
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

#import <UIKit/UIKit.h>

#import "Constants.h"
#import "Preferences.h"
#import "RootController.h"


@implementation Application

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    Preferences *prefs = [Preferences sharedInstance];
#if 0
    if ([prefs firstRun]) {
        // Show a once-only warning
        NSString *title = [NSString stringWithFormat:@"Welcome to %@", @APP_TITLE];
        NSString *message = @FIRST_RUN_MSG;
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:title message:message
                 delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
        [alert show];

        // Save settings so that this warning will not be shown again
        [prefs setFirstRun:NO];
        [prefs writeToDisk];
    }
#endif

    // Create our navigation controller with the initial view controller
    navController = [[UINavigationController alloc] initWithRootViewController:
        [[[RootController alloc] initWithStyle:1] autorelease]];
    [[navController navigationBar] setBarStyle:1];
    [[navController navigationBar] setTintColor:[UIColor colorWithWhite:0.23 alpha:1]];

    // Create and show the application window
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]]; 
    [window addSubview:[navController view]];
    [window makeKeyAndVisible];
}

- (void)dealloc
{
    [navController release];
    [window release];

    [super dealloc];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    Preferences *prefs = [Preferences sharedInstance];
    if ([prefs isModified]) {
        // Write preferences to disk
        [prefs writeToDisk];

        // Respring SpringBoard
        if ([prefs needsRespring])
            notify_post("com.apple.language.changed");
    }
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
