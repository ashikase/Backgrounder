/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-02-11 12:00:26
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


#import "RootController.h"

#include <stdlib.h>

#import <CoreGraphics/CGGeometry.h>

#import <Foundation/Foundation.h>

#import <UIKit/UIViewController-UINavigationControllerItem.h>

#import "AppSpecificPrefsController.h"
#import "Constants.h"
#import "DocumentationController.h"
#import "GlobalPrefsController.h"
#import "Preferences.h"


@implementation RootController

@synthesize displayIdentifiers;


- (id)initWithStyle:(int)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self setTitle:@"Backgrounder"];
        [[self navigationItem] setBackButtonTitle:@"Back"];
    }
    return self;
}

- (void)dealloc
{
    [displayIdentifiers release];
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
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section
{
    switch (section) {
        case 0:
            return @"Documentation";
        case 1:
            return @"Preferences";
        default:
            return nil;
    }
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    switch (section) {
        case 0:
            // Documentation
            return 4;
        case 1:
            // Preferences
            return 2;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdSimple = @"SimpleCell";
    static NSString *reuseIdSafari = @"SafariCell";

    UITableViewCell *cell = nil;
    if (indexPath.section == 0 && indexPath.row == 3) {
        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSafari];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdSafari] autorelease];
            [cell setSelectionStyle:2]; // Gray

            UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
            NSString *labelText = @"(via Safari)";
            [label setText:labelText];
            [label setTextColor:[UIColor colorWithRed:0.2f green:0.31f blue:0.52f alpha:1.0f]];
            UIFont *font = [UIFont systemFontOfSize:16.0f];
            [label setFont:font];
            CGSize size = [labelText sizeWithFont:font];
            [label setFrame:CGRectMake(0, 0, size.width, size.height)];

            [cell setAccessoryView:label];
            [label release];
        }

        [cell setText:@"Project Homepage"];
    } else {
        static NSString *cellTitles[][3] = {
            { @"How to Use", @"Release Notes", @"Known Issues" },
            { @"Global", @"Application-specific", nil }
        };

        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSimple];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdSimple] autorelease];
            [cell setSelectionStyle:2]; // Gray
            [cell setAccessoryType:1]; // Simple arrow
        }
        [cell setText:cellTitles[indexPath.section][indexPath.row]];
    }

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIViewController *vc = nil;

    switch (indexPath.section) {
        case 0:
            {
                // Documentation
                NSString *fileName = nil;
                NSString *title = nil;

                switch (indexPath.row) {
                    case 0:
                        fileName = @"usage.html";
                        title = @"How to Use";
                        break;
                    case 1:
                        fileName = @"release_notes.html";
                        title = @"Release Notes";
                        break;
                    case 2:
                        fileName = @"known_issues.html";
                        title = @"Known Issues";
                        break;
                    case 3:
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@DEVSITE_URL]];
                        break;
                }
                if (fileName && title)
                    [[self navigationController] pushViewController:[[[DocumentationController alloc]
                        initWithContentsOfFile:fileName title:title] autorelease] animated:YES];
            }
            break;
        case 1:
            switch (indexPath.row) {
                case 0:
                    // Global Preferences
                    vc = [[[GlobalPrefsController alloc] initWithStyle:1] autorelease];
                    break;
                case 1:
                    // Application-specific Preferences
                    vc = [[[AppSpecificPrefsController alloc] initWithStyle:1] autorelease];
                    break;
                break;
            }
    }

    if (vc)
        [[self navigationController] pushViewController:vc animated:YES];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
