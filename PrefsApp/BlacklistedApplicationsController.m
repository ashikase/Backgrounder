/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-08-26 00:49:32
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


#import "BlacklistedApplicationsController.h"

#import <objc/runtime.h>

#import <CoreGraphics/CGGeometry.h>
#import <QuartzCore/CALayer.h>

#import <CoreFoundation/CFPreferences.h>

#import <Foundation/Foundation.h>

#import <UIKit/UIAlertView-Private.h>
#import <UIKit/UISwitch.h>
#import <UIKit/UIViewController-UINavigationControllerItem.h>

#import "DocumentationController.h"
#import "Preferences.h"
#import "RootController.h"

// SpringBoardServices
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
extern NSString * SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier);

#define HELP_FILE "blacklisted_apps.html"


static NSInteger compareDisplayNames(NSString *a, NSString *b, void *context)
{
    NSInteger ret;

    NSString *name_a = SBSCopyLocalizedApplicationNameForDisplayIdentifier(a);
    NSString *name_b = SBSCopyLocalizedApplicationNameForDisplayIdentifier(b);
    ret = [name_a caseInsensitiveCompare:name_b];
    [name_a release];
    [name_b release];

    return ret;
}

@implementation BlacklistedApplicationsController

static NSArray *applicationDisplayIdentifiers()
{
    // First, get a list of all possible application paths
    NSMutableArray *paths = [NSMutableArray array];

    // ... scan /Applications (System/Jailbreak applications)
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in [fileManager directoryContentsAtPath:@"/Applications"]) {
        if ([path hasSuffix:@".app"] && ![path hasPrefix:@"."])
           [paths addObject:[NSString stringWithFormat:@"/Applications/%@", path]];
    }

    // ... scan /var/mobile/Applications (AppStore applications)
    for (NSString *path in [fileManager directoryContentsAtPath:@"/var/mobile/Applications"]) {
        for (NSString *subpath in [fileManager directoryContentsAtPath:
                [NSString stringWithFormat:@"/var/mobile/Applications/%@", path]]) {
            if ([subpath hasSuffix:@".app"])
                [paths addObject:[NSString stringWithFormat:@"/var/mobile/Applications/%@/%@", path, subpath]];
        }
    }

    // Then, go through paths and record valid application identifiers
    NSMutableArray *identifiers = [NSMutableArray array];

    for (NSString *path in paths) {
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        if (bundle) {
            NSString *identifier = [bundle bundleIdentifier];

            // Filter out non-applications and apps that should remain hidden
            // FIXME: The proper fix is to only show non-hidden apps and apps
            //        that are in Categories; unfortunately, the design of
            //        Categories does not make it easy to determine what apps
            //        a given folder contains.
            if (identifier &&
                ![identifier hasPrefix:@"jp.ashikase.springjumps."] &&
                ![identifier isEqualToString:@"com.iptm.bigboss.sbsettings"] &&
                ![identifier isEqualToString:@"com.apple.webapp"])
            [identifiers addObject:identifier];
        }
    }

    return identifiers;
}

- (id)initWithStyle:(int)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self setTitle:@"Blacklisted Apps"];
        [[self navigationItem] setBackButtonTitle:@"Back"];
        [[self navigationItem] setRightBarButtonItem:
             [[UIBarButtonItem alloc] initWithTitle:@"Help" style:5
                target:self
                action:@selector(helpButtonTapped)]];

        // Get a copy of the list of currently enabled applications
        blacklistedApplications = [[NSMutableArray alloc]
            initWithArray:[[Preferences sharedInstance] blacklistedApplications]];
    }
    return self;
}

- (void)loadView
{
    // Retain a reference to the root controller for accessing cached info
    // FIXME: Consider passing the display id array in as an init parameter
    rootController = [[[self.parentViewController viewControllers] objectAtIndex:0] retain];

    [super loadView];
}

- (void)dealloc
{
    [busyIndicator release];
    [blacklistedApplications release];
    [rootController release];

    [super dealloc];
}

- (void)enumerateApplications
{
    NSArray *array = applicationDisplayIdentifiers();
    NSArray *sortedArray = [array sortedArrayUsingFunction:compareDisplayNames context:NULL];
    [rootController setDisplayIdentifiers:sortedArray];
    [self.tableView reloadData];

    // Remove the progress indicator
    [busyIndicator hide];
    [busyIndicator release];
    busyIndicator = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    if ([rootController displayIdentifiers] != nil)
        // Application list already loaded
        return;

    // Show a progress indicator
    busyIndicator = [[UIProgressHUD alloc] initWithWindow:[[UIApplication sharedApplication] keyWindow]];
    [busyIndicator setText:@"Loading applications..."];
    [busyIndicator show:YES];

    // Enumerate applications
    // NOTE: Must call via performSelector, or busy indicator does not show in time
    [self performSelector:@selector(enumerateApplications) withObject:nil afterDelay:0.1f];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (isModified)
        [[Preferences sharedInstance] setBlacklistedApplications:blacklistedApplications];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    return nil;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return [[rootController displayIdentifiers] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"BlacklistedAppsCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];
        [cell setSelectionStyle:0];

        UISwitch *toggle = [[UISwitch alloc] init];
        [toggle addTarget:self action:@selector(switchToggled:) forControlEvents:4096]; // ValueChanged
        [cell setAccessoryView:toggle];
        [toggle release];
    }

    NSString *identifier = [[rootController displayIdentifiers] objectAtIndex:indexPath.row];

    NSString *displayName = SBSCopyLocalizedApplicationNameForDisplayIdentifier(identifier);
    [cell setText:displayName];
    [displayName release];

    UIImage *icon = nil;
    NSString *iconPath = SBSCopyIconImagePathForDisplayIdentifier(identifier);
    if (iconPath != nil) {
        icon = [UIImage imageWithContentsOfFile:iconPath];
        icon = [icon _imageScaledToSize:CGSizeMake(35, 36) interpolationQuality:0];
        [iconPath release];
    }
    [cell setImage:icon];

    UISwitch *toggle = [cell accessoryView];
    [toggle setOn:[blacklistedApplications containsObject:identifier]];

    return cell;
}

#pragma mark - Switch delegate

- (void)switchToggled:(UISwitch *)control
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:[control superview]];
    NSString *identifier = [[rootController displayIdentifiers] objectAtIndex:indexPath.row];
    if ([control isOn])
        [blacklistedApplications addObject:identifier];
    else
        [blacklistedApplications removeObject:identifier];
    isModified = YES;
}

#pragma mark - Navigation bar delegates

- (void)helpButtonTapped
{
    // Create and show help page
    [[self navigationController] pushViewController:[[[DocumentationController alloc]
        initWithContentsOfFile:@HELP_FILE title:@"Explanation"] autorelease] animated:YES];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
