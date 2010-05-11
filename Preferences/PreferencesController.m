/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-05-08 06:06:58
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


#import "PreferencesController.h"

#import "Constants.h"
#import "HtmlDocController.h"
#import "Preferences.h"
#import "ToggleButton.h"

extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);


@implementation PreferencesController

- (id)initWithDisplayIdentifier:(NSString *)displayId
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        displayIdentifier = [displayId copy];

        self.title = (displayId == nil) ? @"Global Settings" :
            [SBSCopyLocalizedApplicationNameForDisplayIdentifier(displayId) autorelease];

        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil];
    }
    return self;
}

- (void)dealloc
{
    [displayIdentifier release];
    [super dealloc];
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 4;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    static int rows[] = {3, 2, 2, 1};
    return rows[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdToggle = @"ToggleCell";
    static NSString *reuseIdSimple = @"SimpleCell";

    static NSString *cellTitles[][3] = {
        {@"Off", @"Native", @"Backgrounder"},
        {@"Enable at Launch", @"Stay Enabled", nil},
        {@"Badge", @"Status Bar Icon", nil},
        {@"Minimize on Toggle", nil, nil}
    };
    static NSString *cellSubtitles[][3] = {
        {@"App will terminate on minimize", @"Use native method, if supported", @"Run as if in foreground"},
        {@"No need to manually enable", @"Must be disabled manually", nil},
        {@"Mark the app's icon", @"Mark the app's status bar", nil},
        {@"Minimize the app upon state toggle", nil, nil}
    };

    // All cells access preferences
    Preferences *prefs = [Preferences sharedInstance];

    // The availability of certain options depend on the backgrounding method in use
    BGBackgroundingMethod backgroundingMethod =
        (BGBackgroundingMethod)[prefs integerForKey:kBackgroundingMethod forDisplayIdentifier:displayIdentifier];

    UITableViewCell *cell = nil;
    if (indexPath.section == 0) {
        // Backgrounding method
 
        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSimple];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdSimple] autorelease];
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
        }

        cell.accessoryType = (backgroundingMethod == indexPath.row) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        // Backgrounding indicators, Other

        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdToggle];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdToggle] autorelease];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            ToggleButton *button = [ToggleButton button];
            [button addTarget:self action:@selector(buttonToggled:) forControlEvents:UIControlEventTouchUpInside];
            cell.accessoryView = button;
        }

        static NSString *keys[][2] = {
            {kEnableAtLaunch, kPersistent},
            {kBadgeEnabled, kStatusBarIconEnabled},
            {kMinimizeOnToggle, nil}};

        UIButton *button = (UIButton *)cell.accessoryView;
        button.selected = [prefs boolForKey:keys[indexPath.section - 1][indexPath.row] forDisplayIdentifier:displayIdentifier];

        if (indexPath.section == 2)
            // Set image for cell
            cell.imageView.image = [UIImage imageNamed:((indexPath.row == 0) ? @"badge.png" : @"status_bar_icon.png")];

        if (!(indexPath.section == 2 && indexPath.row == 0)) {
            // Options other than "Badge" are only available for backgrounding method Backgrounder
            if (backgroundingMethod == BGBackgroundingMethodBackgrounder) {
                cell.textLabel.textColor = [UIColor blackColor];
                button.enabled = YES;
            } else {
                cell.textLabel.textColor = [UIColor grayColor];
                button.enabled = NO;
            }
        }
    }

    cell.textLabel.text = cellTitles[indexPath.section][indexPath.row];
    cell.detailTextLabel.text = cellSubtitles[indexPath.section][indexPath.row];

    return cell;
}

#pragma mark - UITableViewDataSource

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // NOTE: When not using custom headers, the table view adds a 10 pixel
    //       offset to the top of the table (presumably the default footer
    //       height).
    return (section == 0) ? 46.0f : 36.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    static NSString *titles[] = {@"Backgrounding method", @"Backgrounding state", @"Indicate status via...", @"Miscellaneous"};

    // Determine offset
    float topOffset = (section == 0) ? 10.0f : 0;

    // Create a container view for the header
    UIView *view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0.0f, 320.0f, 36.0f + topOffset)] autorelease];;

    // Create the text label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(19.0f, 7.0f + topOffset, 320.0f - 19.0f, 21.0f)];
    label.font = [UIFont boldSystemFontOfSize:17.0f];
    label.text = titles[section];
    label.textColor = [UIColor colorWithRed:0.3f green:0.34f blue:0.42f alpha:1.0f];
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(1.0, 1.0f);
    [view addSubview:label];

    // Create the info button
    UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoDark];
    button.center = CGPointMake(view.bounds.size.width - button.bounds.size.width - 1.0f, label.center.y);
    button.tag = section;
    [button addTarget:self action:@selector(helpButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:button];
 
    // Cleanup
    [label release];

    return view;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        // Store the selected option
        [[Preferences sharedInstance] setInteger:indexPath.row forKey:kBackgroundingMethod
            forDisplayIdentifier:displayIdentifier];
        [tableView reloadData];
    }
}

#pragma mark - UIButton delegate

- (void)buttonToggled:(UIButton *)button
{
    static NSString *keys[][2] = {
        {kEnableAtLaunch, kPersistent},
        {kBadgeEnabled, kStatusBarIconEnabled},
        {kMinimizeOnToggle, nil}};

    // Update selected state of button
    button.selected = !button.selected;

    // Update preference
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)[button superview]];
    [[Preferences sharedInstance] setBool:button.selected forKey:keys[indexPath.section - 1][indexPath.row]
        forDisplayIdentifier:displayIdentifier];
}

#pragma mark - Navigation bar delegates

- (void)helpButtonTapped:(UIButton *)sender
{
    static NSString *helpFiles[] = {@"help_method.mdwn", @"help_state.mdwn", @"help_indicators.mdwn", @"help_misc.mdwn"};

    // Create and show help page
    // NOTE: Controller is released in delegate callback
    HtmlDocController *docCont = [[HtmlDocController alloc]
        initWithContentsOfFile:helpFiles[sender.tag] templateFile:@"template.html" title:@"Help"];
    docCont.delegate = self;
}

#pragma mark - HtmlDocController delegate

- (void)htmlDocControllerDidFinishLoading:(HtmlDocController *)docCont
{
    [self presentModalViewController:[docCont autorelease] animated:YES];
}

- (void)htmlDocControllerDidFailToLoad:(HtmlDocController *)docCont
{
    [docCont autorelease];
}

@end

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
