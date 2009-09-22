/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-08-26 00:49:29
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


#import "InvocationMethodController.h"

#import <CoreGraphics/CGGeometry.h>
#import <QuartzCore/CALayer.h>

#import <Foundation/Foundation.h>

#import <UIKit/UIViewController-UINavigationControllerItem.h>

#import "DocumentationController.h"
#import "MultiLineCell.h"
#import "Preferences.h"

#define HELP_FILE "invocation_method.html"


@implementation InvocationMethodController

- (id)initWithStyle:(int)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self setTitle:@"Invocation Method"];
        [[self navigationItem] setBackButtonTitle:@"Back"];
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
    return nil;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    return 1;
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0f * 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"PreferencesCell";

    MultiLineCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        // Cell does not exist, create a new one
        cell = [[[MultiLineCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];
        [cell setSelectionStyle:2]; // Gray
    }

    NSString *title = nil;
    NSString *description = nil;
    NSString *imageName = nil;

    if (indexPath.section == 0) {
        title = @"Hold Home Button";
        description = @"Press and hold the home button until the Backgrounder pop-up appears.";
        imageName = @"invoke_hold.png";
    } else {
        title = @"Double-tap Home Button";
        description = @"Quickly press and release the home button twice, like double-clicking a mouse.";
        imageName = @"invoke_dbltap.png";
    }

    [cell setTitle:title];
    [cell setDescription:description];

    NSString *imagePath = [NSString stringWithFormat:@"%@/images/%@",
             [[NSBundle mainBundle] bundlePath], imageName];
    [cell setImage:[UIImage imageWithContentsOfFile:imagePath]];

    if ([[Preferences sharedInstance] invocationMethod] == indexPath.section)
        [cell setAccessoryType:3];

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Store the selected option
    [[Preferences sharedInstance] setInvocationMethod:indexPath.section];

    // Return to the previous view controller
    [[self navigationController] popViewControllerAnimated:YES];
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
