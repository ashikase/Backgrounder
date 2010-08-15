/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-08-08 18:25:31
 */

/**
 * Copyright (C) 2008-2010  Lance Fetters (aka. ashikase)
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


#import "RootController.h"

#import <QuartzCore/QuartzCore.h>
#import <libactivator/libactivator.h>

#import "Constants.h"
#import "DocumentationController.h"
#import "OverridesController.h"
#import "Preferences.h"
#import "PreferencesController.h"


@implementation RootController

@synthesize displayIdentifiers;


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Backgrounder";
        self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
            initWithImage:[UIImage imageNamed:@"reset_defaults.png"] style:UIBarButtonItemStyleDone
            target:self action:@selector(resetButtonTapped)] autorelease];

    }
    return self;
}

- (void)dealloc
{
    [displayIdentifiers release];
    [super dealloc];
}

- (void)viewDidLoad
{
    // Create and add footer view

    // Determine size of application frame (iPad, iPhone differ)
    CGRect appFrame = [[UIScreen mainScreen] applicationFrame];

    // Determine height of table data
    int sections = [self.tableView numberOfSections];
    CGRect rect = [self.tableView rectForSection:(sections - 1)];
    float height = rect.origin.y + rect.size.height;

    // Table height is app frame height - navigation bar height (44.0f)
    UIView *view = [[UIView alloc] initWithFrame:
        CGRectMake(0, 0, appFrame.size.width, appFrame.size.height - 44.0f - height)];

    // Donation button
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button addTarget:self action:@selector(openDonationLink) forControlEvents:UIControlEventTouchUpInside];
    UIImage *image = [UIImage imageNamed:@"donate.png"];
    [button setImage:image forState:UIControlStateNormal];
    button.frame = CGRectMake((appFrame.size.width - image.size.width) / 2.0f, view.bounds.size.height - image.size.height - 10.0f,
            image.size.width, image.size.height);
    [view addSubview:button];

    // Note height of donation button
    float donationHeight = image.size.height;

    // Author label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    [label setText:@"by Lance Fetters (ashikase)"];
    [label setTextColor:[UIColor colorWithRed:0.3f green:0.34f blue:0.42f alpha:1.0f]];
    [label setShadowColor:[UIColor whiteColor]];
    [label setShadowOffset:CGSizeMake(1, 1)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:16.0f]];
    CGSize size = [label.text sizeWithFont:label.font];
    [label setFrame:CGRectMake((appFrame.size.width - size.width) / 2.0f, view.bounds.size.height - donationHeight - size.height - 12.0f,
            size.width, size.height)];
    [view addSubview:label];
    [label release];

    self.tableView.tableFooterView = view;
    [view release];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 3;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    static int rows[] = {2, 1, 1};
    return rows[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdSubtitle = @"SubtitleCell";

    static NSString *cellTitles[][2] = {
        {@"Global", @"Overrides"},
        {@"Control (via Activator) *", nil},
        {@"Documentation", nil}};

    static NSString *cellSubtitles[][2] = {
        {@"Settings used by all apps", @"Override global settings for chosen apps"},
        {@"Set event used to toggle backgrounding", nil},
        {@"Usage, FAQ, Release Notes, etc.", nil}};

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSubtitle];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdSubtitle] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.textLabel.text = cellTitles[indexPath.section][indexPath.row];
    cell.detailTextLabel.text = cellSubtitles[indexPath.section][indexPath.row];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    CGFloat heights[] = {0, 0, 25.0f};
    return heights[section];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    // NOTE: Must create custom view in order to change the font color.
 
    UIView *view = nil;
    if (section == 2) {
        // Determine size of application frame (iPad, iPhone differ)
        CGRect appFrame = [[UIScreen mainScreen] applicationFrame];

        // Create a container view for the header
        view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0.0f, appFrame.size.width, 19.0f)] autorelease];;

        // Create the text label
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5.0f, 6.0f, appFrame.size.width - 10.0f, 19.0f)];
        label.font = [UIFont systemFontOfSize:15.0f];
        label.text = @"Please read the FAQ before requesting help.";
        label.textColor = [UIColor whiteColor];
        label.textAlignment = UITextAlignmentCenter;
        label.backgroundColor = [UIColor colorWithRed:0.6f green:0.1f blue:0.2f alpha:1.0f];
        label.layer.cornerRadius = 5.0f;
        label.layer.borderColor = [[UIColor colorWithRed:0.9f green:0.1f blue:0.2f alpha:1.0f] CGColor];
        label.layer.borderWidth = 1.0f;

        // Resize label to fit text
        // NOTE: Add 10 pixels to width for padding.
        const float height = 19.0f;
        CGSize size = [label.text sizeWithFont:label.font constrainedToSize:CGSizeMake(CGFLOAT_MAX, height)
            lineBreakMode:UILineBreakModeWordWrap];
        float width = size.width + 10.0f;
        label.frame = CGRectMake((appFrame.size.width - width) / 2.0f, 10.0f, width, height);

        // Add the label to the view
        [view addSubview:label];
        [label release];
    }

    return view;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIViewController *vc = nil;

    switch (indexPath.section) {
        case 0:
            if (indexPath.row == 0)
                // Defaults
                vc = [[[PreferencesController alloc] initWithDisplayIdentifier:nil] autorelease];
            else
                // Overrides
                vc = [[[OverridesController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
            break;
        case 1:
            // Control
            vc = [[[LAListenerSettingsViewController alloc] init] autorelease];
            [(LAListenerSettingsViewController *)vc setListenerName:@APP_ID];
            break;
        case 2:
            // Documentation
            vc = [[[DocumentationController alloc] initWithStyle:1] autorelease];
            break;
        default:
            break;
    }

    if (vc)
        [[self navigationController] pushViewController:vc animated:YES];
}

#pragma mark - UIButton delegate

- (void)openDonationLink
{
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=gaizin%40gmail%2ecom&lc=US&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHostedGuest"]];
}

#pragma mark - Navigation bar button actions

- (void)resetButtonTapped
{
    UIAlertView *alertView = [[[UIAlertView alloc]  initWithTitle:@"Reset to Defaults"
        message:@"Are you sure you wish to reset all settings to their default values?"
       delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil] autorelease];
    [alertView show];
}

#pragma mark - UIAlertView delegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        // User pressed "Yes"; reset settings to default values
        [[Preferences sharedInstance] resetToDefaults];

        // Remove all currently-assigned Activator events
        LAActivator *activator = [LAActivator sharedInstance];
        NSArray *events = [activator eventsAssignedToListenerWithName:@APP_ID];
        for (LAEvent *event in events)
            [activator unassignEvent:event];

        // Set default Activator event
        [activator assignEvent:[LAEvent eventWithName:LAEventNameMenuHoldShort] toListenerWithName:@APP_ID];
    }
}

@end

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
