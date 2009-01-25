/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-01-25 20:04:22
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

#import "Constants.h"
#import "DocumentationController.h"
#import "EnabledApplicationsController.h"
#import "FeedbackTypeController.h"
#import "InvocationMethodController.h"
#import "Preferences.h"


@implementation RootController

@synthesize displayIdentifiers;


- (id)initWithStyle:(int)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self setTitle:@"Backgrounder Prefs"];
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

- (void)viewWillDisappear:(BOOL)animated
{
    Preferences *prefs = [Preferences sharedInstance];
    if ([prefs isModified]) {
        // Write preferences to disk
        [prefs writeUserDefaults];

        // Respring SpringBoard
        notify_post("com.apple.language.changed");
    }
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
            return @"Documentation";
        case 1:
            return @"General";
        case 2:
            return @"Applications";
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
            // General
            return 2;
        case 2:
            // Applications
            return 1;
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
        // Try to retrieve from the table view a now-unused cell with the given identifier
        cell = [tableView dequeueReusableCellWithIdentifier:reuseIdSimple];
        if (cell == nil) {
            // Cell does not exist, create a new one
            cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdSimple] autorelease];
            [cell setSelectionStyle:2]; // Gray
            [cell setAccessoryType:1]; // Simple arrow
        }

        switch (indexPath.section) {
            case 0:
                // Documentation
                switch (indexPath.row) {
                    case 0:
                        [cell setText:@"How to Use"];
                        break;
                    case 1:
                        [cell setText:@"Release Notes"];
                        break;
                    case 2:
                        [cell setText:@"Known Issues"];
                        break;
                }
                break;
            case 1:
                // General
                if (indexPath.row == 0) {
                    [cell setText:@"Mode"];
                } else {
                    [cell setText:@"Invocation method"];
                }
                break;
            case 2:
                // Applications
                [cell setText:@"Enabled at launch"];
                break;
        }
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

                switch (indexPath.section) {
                    case 0:
                        {
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
                }
            }
            break;
        case 1:
            // General
            if (indexPath.row == 0) {
                // Operating mode
                vc = [[[FeedbackTypeController alloc] initWithStyle:1] autorelease];
                break;
            } else if (indexPath.row == 1) {
                // Invocation method
                vc = [[[InvocationMethodController alloc] initWithStyle:1] autorelease];
                break;
            }
            break;
        case 2:
            // Applications
            vc = [[[EnabledApplicationsController alloc] initWithStyle:1] autorelease];
            break;
    }

    if (vc)
        [[self navigationController] pushViewController:vc animated:YES];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
