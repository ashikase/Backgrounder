/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-04-29 20:30:48
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


#import "OverridesController.h"

#import "ApplicationCell.h"
#import "Preferences.h"
#import "PreferencesController.h"


@implementation OverridesController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Overrides";
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add"
            style:UIBarButtonItemStyleBordered target:self action:@selector(addButtonTapped:)];
    }
    return self;
}

- (void)loadView
{
    [super loadView];

    // Set the table to edit mode so that delete buttons are shown
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
}

- (void)dealloc
{
    [applications release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Update the table contents
    [applications release];
    applications = [[[[Preferences sharedInstance] objectForKey:kOverrides] allKeys] retain];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return [applications count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"ApplicationCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    ApplicationCell *cell = (ApplicationCell *)[tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[ApplicationCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    cell.displayId = [applications objectAtIndex:indexPath.row];

    return cell;
}

- (void)tableView:(UITableView *)tableView
  commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Remove settings for the selected application
        NSString *displayId = [applications objectAtIndex:indexPath.row];
        [[Preferences sharedInstance] removeOverrideForDisplayId:displayId];

        // Update the applications array
        [applications autorelease];
        applications = [[[[Preferences sharedInstance] objectForKey:kOverrides] allKeys] retain];

        // Update the table
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [tableView endUpdates];
    }
}

#pragma mark - UITableViewCellDelegate

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Display settings for the selected application
    NSString *identifier = [applications objectAtIndex:indexPath.row];
    UIViewController *vc = [[[PreferencesController alloc] initWithDisplayIdentifier:identifier] autorelease];
    [[self navigationController] pushViewController:vc animated:YES];
}

#pragma mark - Actions

- (void)addButtonTapped:(id)sender
{
    // Display list of applications
    UIViewController *vc = [[[ApplicationPickerController alloc] initWithDelegate:self] autorelease];
    [self presentModalViewController:vc animated:YES];
}

#pragma mark - ApplicationPickerControllerDelegate methods

- (void)applicationPickerController:(ApplicationPickerController *)controller didSelectAppWithDisplayIdentifier:(NSString *)displayId
{
    // Add settings for the selected application
    [[Preferences sharedInstance] addOverrideForDisplayId:displayId];

    // Dismiss the application picker
    [self dismissModalViewControllerAnimated:YES];
}

- (void)applicationPickerControllerDidFinish:(ApplicationPickerController *)controller
{
    // Dismiss the application picker
    [self dismissModalViewControllerAnimated:YES];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
