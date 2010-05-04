/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-04-23 01:45:23
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


#import "GlobalPrefsController.h"

#import "Constants.h"
#import "HtmlDocController.h"
#import "Preferences.h"
#import "ToggleButton.h"

#define HELP_FILE "global_prefs.mdwn"


@implementation GlobalPrefsController


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Global";
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil];
        [[self navigationItem] setRightBarButtonItem:
             [[UIBarButtonItem alloc] initWithTitle:@"Help" style:5
                target:self
                action:@selector(helpButtonTapped)]];
    }
    return self;
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    static NSString *titles[] = {nil, @"Indicate backgrounding status via..."};
    return titles[section];
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    int rows = 0;
    if (section == 0)
        rows = 1;
    else
        rows = [[Preferences sharedInstance] boolForKey:kBadgeEnabled] ? 2 : 1;
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdToggle = @"ToggleCell";

    //static NSString *cellTitles[] = {@"Persistence", @"Animations", @"Badge"};
    static NSString *cellTitles[][2] = {
        {@"Backgrounding Persists", nil},
        {@"Badge", @"... include Mail, iPod, etc."}
    };
    static NSString *cellSubtitles[][2] = {
        {@"Must manually disable", nil},
        {@"Mark icons of running apps", @"Apps with built-in backgrounding"}
    };

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdToggle];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdToggle] autorelease];
        [cell setSelectionStyle:0];

        ToggleButton *button = [ToggleButton button];
        [button addTarget:self action:@selector(buttonToggled:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = button;
    }
    cell.textLabel.text = cellTitles[indexPath.section][indexPath.row];
    cell.detailTextLabel.text = cellSubtitles[indexPath.section][indexPath.row];

    UIButton *button = (UIButton *)[cell accessoryView];
    switch (indexPath.section) {
        case 0:
            button.selected = [[Preferences sharedInstance] boolForKey:kPersistent];
            cell.imageView.image = nil;
            break;
        case 1:
            switch (indexPath.row) {
                case 0:
                    button.selected = [[Preferences sharedInstance] boolForKey:kBadgeEnabled];
                    cell.imageView.image = [UIImage imageNamed:@"badge.png"];
                    break;
                case 1:
                    button.selected = [[Preferences sharedInstance] boolForKey:kBadgeEnabledForAll];
                    break;
                default:
                    break;
            }
        default:
            break;
    }
    return cell;
}

#pragma mark - UIButton delegate

- (void)buttonToggled:(UIButton *)button
{
    // Update selected state of button
    button.selected = !button.selected;

    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)[button superview]];
    switch (indexPath.section) {
        case 0:
            [[Preferences sharedInstance] setBool:button.selected forKey:kPersistent];
            break;
        case 1:
            switch (indexPath.row) {
                case 0:
                    [[Preferences sharedInstance] setBool:button.selected forKey:kBadgeEnabled];

                    // Animate showing/hiding of suboption
                    NSArray *indexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:1 inSection:1], nil];
                    if (button.selected)
                        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
                    else
                        [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
                    break;
                case 1:
                    [[Preferences sharedInstance] setBool:button.selected forKey:kBadgeEnabledForAll];
                    break;
                default:
                    break;
            }
            break;
    }
}

#pragma mark - Navigation bar delegates

- (void)helpButtonTapped
{
    // Create and show help page
    UIViewController *vc = [[[HtmlDocController alloc]
        initWithContentsOfFile:@HELP_FILE title:@"Explanation"]
        autorelease];
    [(HtmlDocController *)vc setTemplateFileName:@"template.html"];
    [[self navigationController] pushViewController:vc animated:YES];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
