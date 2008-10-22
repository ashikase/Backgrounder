/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-22 19:06:18
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
typedef struct {} CDAnonymousStruct2;
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

#define HELP_FILE "/mainPage.html"


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
        [[self navigationItem] setRightBarButtonItem:
             [[UIBarButtonItem alloc] initWithTitle:@"Help" style:5
                target:self
                action:@selector(helpButtonTapped)]];
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

- (void)setSaveButtonEnabled:(BOOL)enable
{
    UIBarButtonItem *item = nil;
    if (enable)
        item = [[[UIBarButtonItem alloc] initWithTitle:@"Save" style:2
            target:self action:@selector(saveButtonClicked)] autorelease];
    [[self navigationItem] setLeftBarButtonItem:item];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
    [table deselectRowAtIndexPath:[table indexPathForSelectedRow] animated:YES];

    // If preferences have changed, show the save button
    if ([[Preferences sharedInstance] isModified])
        [self setSaveButtonEnabled:YES];
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
            return 2;
        case 2:
            // Help
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
            if (indexPath.row == 0) {
                [cell setText:@"Enabled at launch"];
            } else {
                [cell setText:@"Suspend on toggle"];
                [cell setAccessoryType:0];
                [cell setSelectionStyle:0];
                UISwitch *toggle = [[UISwitch alloc] init];
                [toggle setOn:[[Preferences sharedInstance] shouldSuspend]];
                [toggle addTarget:self action:@selector(switchToggled:) forControlEvents:64];
                [cell setAccessoryView:toggle];
                [toggle release];
            }
            break;
        case 2:
            // Other
            [cell setText:@"Visit the project homepage"];
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
            } else {
                // Suspend on toggle
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

#pragma mark - Navigation bar delegates

- (void)saveButtonClicked
{
    // Save the preferences to disk
    [[Preferences sharedInstance] writeUserDefaults];

    // Ask if user wants to restart now
    UIActionSheet *sheet = [[[UIActionSheet alloc]
        initWithTitle:@"SpringBoard must be restarted for changes to take effect."
             delegate:self cancelButtonTitle:@"Return to SpringBoard" destructiveButtonTitle:@"Restart Now" otherButtonTitles:nil] autorelease];
    [sheet setActionSheetStyle:1];
    [sheet showInView:[self view]];
}

#pragma mark - UIActionSheet delegates

- (void)actionSheet:(UIActionSheet *)sheet didDismissWithButtonIndex:(int)index
{
    if (index == 0)
        // Kill SpringBoard (will be relaunched automatically)
        system("/usr/bin/killall SpringBoard");
    else
        // Exit to SpringBoard
        [[UIApplication sharedApplication] suspendWithAnimation:NO];
}

#pragma mark - Switch delegate

- (void)switchToggled:(UISwitch *)control
{
    [[Preferences sharedInstance] setShouldSuspend:[control isOn]];
    if ([[Preferences sharedInstance] isModified])
        [self setSaveButtonEnabled:YES];
}

#pragma mark - Navigation bar delegates

- (void)helpButtonTapped
{
    // Create and show help popup
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *filePath = [bundlePath stringByAppendingString:@HELP_FILE];

    HtmlAlertView *alertView = [[[HtmlAlertView alloc]
        initWithContentsOfFile:filePath title:@"Explanation"] autorelease];

    [alertView show];
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
        Preferences *settings = [Preferences sharedInstance];
        [settings registerDefaults];
        [settings readUserDefaults];

        [[self navigationBar] setBarStyle:1];
        [self pushViewController:
            [[[PreferencesPage alloc] init] autorelease] animated:NO];
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
