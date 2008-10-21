/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-21 21:49:39
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

#import "EnabledApplicationsController.h"

#import <objc/runtime.h>

#import <CoreGraphics/CGGeometry.h>
#import <QuartzCore/CALayer.h>

#import <CoreFoundation/CFPreferences.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>

#import <UIKit/NSIndexPath-UITableView.h>
#import <UIKit/UIActivityIndicatorView.h>
typedef struct {} CDAnonymousStruct2;
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIImage-UIImageInternal.h>
#import <UIKit/UILabel.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UINavigationItem.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UISwitch.h>
@protocol UITableViewDataSource;
#import <UIKit/UITableView.h>
#import <UIKit/UITableViewCell.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>
#import <UIKit/UIViewController-UINavigationControllerItem.h>

#import "HtmlAlertView.h"
#import <UIKit/UIAlertView-Private.h>

#import "Preferences.h"
#import "PreferencesController.h"

extern id SBSCopyApplicationDisplayIdentifiers(BOOL onlyActive, BOOL unknown);
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
extern NSString * SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier);


static NSInteger compareDisplayNames(NSString *a, NSString *b, void *context)
{
    NSString *name_a = SBSCopyLocalizedApplicationNameForDisplayIdentifier(a);
    NSString *name_b = SBSCopyLocalizedApplicationNameForDisplayIdentifier(b);
    return [name_a caseInsensitiveCompare:name_b];
}

@implementation EnabledApplicationsController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self setTitle:@"Enabled Apps"];
        [[self navigationItem] setRightBarButtonItem:
             [[UIBarButtonItem alloc] initWithTitle:@"Help" style:5
                target:self
                action:@selector(helpButtonTapped)]];

        // Get a copy of the list of currently enabled applications
        enabledApplications = [[NSMutableArray alloc]
            initWithArray:[[Preferences sharedInstance] enabledApplications]];
    }
    return self;
}

- (void)loadView
{
    table = [[UITableView alloc]
        initWithFrame:[[UIScreen mainScreen] applicationFrame] style:1];
    [table setDataSource:self];
    [table setDelegate:self];
    [table reloadData];
    [self setView:table];
}

- (void)dealloc
{
    [table setDataSource:nil];
    [table setDelegate:nil];
    [table release];

    [enabledApplications release];

    [super dealloc];
}

- (void)enumerateApplications
{
    NSArray *array = SBSCopyApplicationDisplayIdentifiers(NO, NO);
    NSArray *sortedArray = [array sortedArrayUsingFunction:compareDisplayNames context:NULL];
    [[self navigationController] setDisplayIdentifiers:sortedArray];
    [array release];
    [table reloadData];

    // Remove the progress indicator
    [busyIndicator dismiss];
    [busyIndicator release];
}

- (void)viewDidAppear:(BOOL)animated
{
    if ([[self navigationController] displayIdentifiers] != nil)
        // Application list already loaded
        return;

    // Create a progress indicator
    busyIndicator = [[UIAlertView alloc] init];
    [busyIndicator setAlertSheetStyle:2];
    [busyIndicator setDimsBackground:false];
    [busyIndicator setRunsModal:false];

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:0];
    [spinner setCenter:CGPointMake(29, 44)];
    [spinner startAnimating];
    [busyIndicator addSubview:spinner];
    [spinner release];

    UILabel *label = [[UILabel alloc] init];
    [label setFont:[UIFont boldSystemFontOfSize:20.0f]];
    [label setText:@"Loading applications..."];
    [label setTextColor:[UIColor whiteColor]];
    [label setBackgroundColor:[UIColor clearColor]];
    [label sizeToFit];
    [label setCenter:CGPointMake(166, 44)];
    [busyIndicator addSubview:label];
    [label release];

    // Show the indicator
    [busyIndicator popupAlertAnimated:NO];

    // Enumerate applications
    // NOTE: Must call via performSelector, or busy indicator does not show in time
    [self performSelector:@selector(enumerateApplications) withObject:nil afterDelay:0.1f];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (isModified)
        [[Preferences sharedInstance] setEnabledApplications:enabledApplications];
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
    return [[[self navigationController] displayIdentifiers] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"EnabledApplicationsCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil)
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];

    NSString *identifier = [[[self navigationController] displayIdentifiers] objectAtIndex:indexPath.row];

    NSString *displayName = SBSCopyLocalizedApplicationNameForDisplayIdentifier(identifier);
    [cell setText:displayName];

    NSString *iconPath = SBSCopyIconImagePathForDisplayIdentifier(identifier);
    if (iconPath != nil) {
        UIImage *icon = [UIImage imageWithContentsOfFile:iconPath];
        icon = [icon _imageScaledToSize:CGSizeMake(35, 36) interpolationQuality:0];
        [cell setImage:icon];
    }

    UISwitch *toggle = [[UISwitch alloc] init];
    [toggle setOn:[enabledApplications containsObject:identifier]];
    [toggle addTarget:self action:@selector(switchToggled:) forControlEvents:64];
    [cell setAccessoryView:toggle];
    [toggle release];

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[self navigationController] popToRootViewControllerAnimated:YES];
}

#pragma mark - Navigation bar delegates

- (void)helpButtonTapped
{
    // Create and show help popup
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *filePath = [bundlePath stringByAppendingString:@"/enabledApplications.html"];

    HtmlAlertView *alertView = [[[HtmlAlertView alloc]
        initWithContentsOfFile:filePath title:@"Explanation"] autorelease];

    [alertView show];
}

#pragma mark - Switch delegate

- (void)switchToggled:(UISwitch *)control
{
    NSArray *displayIdentifiers = [[self navigationController] displayIdentifiers];

    NSIndexPath *indexPath = [table indexPathForCell:[control superview]];
    NSString *identifier = [displayIdentifiers objectAtIndex:indexPath.row];
    if ([control isOn])
        [enabledApplications addObject:identifier];
    else
        [enabledApplications removeObject:identifier];
    isModified = YES;
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
