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


#import "AppSpecificPrefsController.h"

#include <stdlib.h>

#import <CoreGraphics/CGGeometry.h>

#import <Foundation/Foundation.h>

#import <UIKit/UISwitch.h>
#import <UIKit/UIViewController-UINavigationControllerItem.h>

#import "Constants.h"
#import "DocumentationController.h"
#import "BlacklistedApplicationsController.h"
#import "EnabledApplicationsController.h"
#import "Preferences.h"

#define HELP_FILE "appspecific_prefs.html"


@implementation AppSpecificPrefsController


- (id)initWithStyle:(int)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self setTitle:@"App-specific"];
        [[self navigationItem] setBackButtonTitle:@"Back"];
#if 0
        [[self navigationItem] setRightBarButtonItem:
             [[UIBarButtonItem alloc] initWithTitle:@"Help" style:5
                target:self
                action:@selector(helpButtonTapped)]];
#endif
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
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
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdSimple = @"SimpleCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSimple];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdSimple] autorelease];
        [cell setSelectionStyle:2]; // Gray
        [cell setAccessoryType:1]; // Simple arrow
    }
    [cell setText:(indexPath.row == 0) ? @"Always-enabled" : @"Blacklisted"];

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIViewController *vc = nil;
    if (indexPath.row == 0)
        vc = [[[EnabledApplicationsController alloc] initWithStyle:1] autorelease];
    else
        vc = [[[BlacklistedApplicationsController alloc] initWithStyle:1] autorelease];
    if (vc)
        [[self navigationController] pushViewController:vc animated:YES];
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
