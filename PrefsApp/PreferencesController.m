/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-12-25 20:28:47
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

#import "PreferencesController.h"

#include <stdlib.h>

#import <CoreGraphics/CGGeometry.h>

#import <Foundation/NSBundle.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSURL.h>

// FIXME: move CDAnonymousStruct typedefs to a separate header file
#import "HtmlAlertView.h"

#import <UIKit/NSIndexPath-UITableView.h>
@protocol UIActionSheetDelegate;
#import <UIKit/UIActionSheet.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIBezierPath-UIInternal.h>
#import <UIKit/UIFieldEditor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UINavigationBar.h>
#import <UIKit/UINavigationItem.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UISimpleTableCell.h>
#import <UIKit/UISwitch.h>
@protocol UITableViewDataSource;
#import <UIKit/UITableView.h>
#import <UIKit/UITableViewCell.h>
#import <UIKit/UIViewController-UINavigationControllerItem.h>

#import "EnabledApplicationsController.h"
#import "FeedbackTypeController.h"
#import "InvocationMethodController.h"
#import "Preferences.h"


@interface PreferencesPage : UIViewController
{
    UITableView *table;
}

@end

//______________________________________________________________________________

@implementation PreferencesPage

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self setTitle:@"Backgrounder Prefs"];
        [[self navigationItem] setBackButtonTitle:@"Back"];
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

    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
    [table deselectRowAtIndexPath:[table indexPathForSelectedRow] animated:YES];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    switch (section) {
        case 0:
            return @"General";
        case 1:
            return @"Applications";
        case 2:
            return @"Other";
        default:
            return nil;
    }
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    switch (section) {
        case 0:
            // General
            return 2;
        case 1:
            // Applications
            return 1;
        case 2:
            // Other
            return 1;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"PreferencesCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil)
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];

    // The majority of cells direct to a secondary page
    [cell setAccessoryType:1];

    switch (indexPath.section) {
        case 0:
            // General
            if (indexPath.row == 0) {
                [cell setText:@"Invocation method"];
            } else {
                [cell setText:@"Feedback type"];
            }
            break;
        case 1:
            // Applications
            [cell setText:@"Enabled at launch"];
            break;
        case 2:
            // Other
            [cell setText:@"Visit the project homepage"];
            [cell setAccessoryType:0];
            break;
    }

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:
            // General
            if (indexPath.row == 0) {
                // Invocation method
                UIViewController *vc = [[[InvocationMethodController alloc] init] autorelease];
                [[self navigationController] pushViewController:vc animated:YES];
                break;
            } else if (indexPath.row == 1) {
                // Feedback type
                UIViewController *vc = [[[FeedbackTypeController alloc] init] autorelease];
                [[self navigationController] pushViewController:vc animated:YES];
                break;
            }
            break;
        case 1:
            // Applications
            {
                UIViewController *vc = [[[EnabledApplicationsController alloc] init] autorelease];
                [[self navigationController] pushViewController:vc animated:YES];
            }
            break;
        case 2:
            // Other
            if (indexPath.row == 0)
                // Documentation
                [[UIApplication sharedApplication] openURL:
                                      [NSURL URLWithString:@"http://code.google.com/p/iphone-backgrounder/wiki/Documentation"]];
            else 
                break;
            break;
    }
}

@end

//______________________________________________________________________________
//______________________________________________________________________________

@implementation PreferencesController

@synthesize displayIdentifiers;

- (id)init
{
    self = [super init];
    if (self) {
        Preferences *prefs = [Preferences sharedInstance];
        [prefs registerDefaults];
        [prefs readUserDefaults];

        [[self navigationBar] setBarStyle:1];
        [self pushViewController:
            [[[PreferencesPage alloc] init] autorelease] animated:NO];

        if ([prefs firstRun]) {
            // Show a once-only warning
            UIAlertView *alert = [[[UIAlertView alloc]
                initWithTitle:@"Welcome to Backgrounder"
                message:@"WARNING: Any changes made to preferences will cause SpringBoard to be restarted upon exit."
                delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
            [alert show];

            // Save settings so that this warning will not be shown again
            [prefs setFirstRun:NO];
            [prefs writeUserDefaults];
        }
    }
    return self;
}

- (void)dealloc
{
    [displayIdentifiers release];
    [super dealloc];
}
@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
