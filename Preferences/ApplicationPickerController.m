/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-05-04 20:24:15
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


#import "ApplicationPickerController.h"

#import "ApplicationCell.h"
#import "Preferences.h"

// SpringBoardServices
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
extern NSString * SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier);
extern NSArray * SBSCopyApplicationDisplayIdentifiers(BOOL activeOnly, BOOL unknown);

@interface UIProgressHUD : UIView

- (id)initWithWindow:(id)fp8;
- (void)setText:(id)fp8;
- (void)show:(BOOL)fp8;
- (void)hide;

@end

//==============================================================================

static NSInteger compareDisplayNames(NSString *a, NSString *b, void *context)
{
    NSInteger ret;

    NSString *name_a = SBSCopyLocalizedApplicationNameForDisplayIdentifier(a);
    NSString *name_b = SBSCopyLocalizedApplicationNameForDisplayIdentifier(b);
    ret = [name_a caseInsensitiveCompare:name_b];
    [name_a release];
    [name_b release];

    return ret;
}

//==============================================================================

static NSArray *applicationDisplayIdentifiers()
{
    // Get list of non-hidden applications
    NSArray *nonhidden = SBSCopyApplicationDisplayIdentifiers(NO, NO);

    // Get list of hidden applications (assuming LibHide is installed)
    NSArray *hidden = nil;
    NSString *filePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LibHide/hidden.plist"];
    id value = [[NSDictionary dictionaryWithContentsOfFile:filePath] objectForKey:@"Hidden"];
    if ([value isKindOfClass:[NSArray class]])
        hidden = (NSArray *)value;

    // Record list of valid identifiers
    NSMutableArray *identifiers = [NSMutableArray array];
    for (NSArray *array in [NSArray arrayWithObjects:nonhidden, hidden, nil]) {
        for (NSString *identifier in array) {
            // Filter out non-apps and apps that are not executed directly
            // FIXME: Should Categories folders be in this list? Categories
            //        folders are apps, but when used with CategoriesSB they are
            //        non-apps.
            if (identifier
                    && ![identifier hasPrefix:@"jp.ashikase.springjumps."]
                    && ![identifier isEqualToString:@"com.iptm.bigboss.sbsettings"]
                    && ![identifier isEqualToString:@"com.apple.webapp"])
            [identifiers addObject:identifier];
        }
    }

    // Clean-up
    [nonhidden release];

    return identifiers;
}

//==============================================================================

// Create an array to cache the result of application enumeration
// NOTE: Once created, this global will exist until program termination.
static NSArray *allApplications = nil;

@interface ApplicationPickerController (Private)
- (void)findAvailableItems;
@end

@implementation ApplicationPickerController

@synthesize delegate;

- (id)initWithDelegate:(id<ApplicationPickerControllerDelegate>)delegate_
{
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		delegate = delegate_;
	}
	return self;
}

- (void)loadView
{
	// Create a navigation bar
	UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 44.0f)];
	navBar.barStyle = UIBarStyleBlackOpaque;
    navBar.tintColor = [UIColor colorWithWhite:0.23 alpha:1];
	navBar.delegate = self;

	// Add title and buttons to navigation bar
	UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"Applications"];
    navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Done"
            style:UIBarButtonItemStyleBordered target:self action:@selector(doneButtonTapped)] autorelease];
	[navBar pushNavigationItem:navItem animated:NO];
	[navItem release];

	// Create a table
	// NOTE: Height is screen height - nav bar
	appsTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44.0f, 320.0f, 460.0f - 44.0f)];
	appsTableView.dataSource = self;
	appsTableView.delegate = self;
	//[appsTableView setSeparatorStyle:2]; /* 0 no lines, 1 thin lines, 2 bold lines */

	// Create a view to hold the navigation bar and table
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    [view addSubview:navBar]; 
    [view addSubview:appsTableView]; 
	[navBar release];

    self.view = view;
}

- (void)dealloc
{
    [busyIndicator release];
    [appsTableView release];
    [applications release];

    [super dealloc];
}

- (void)loadFilteredList
{
    [applications release];
    applications = [allApplications mutableCopy];
    [applications removeObjectsInArray:[[[Preferences sharedInstance] objectForKey:kOverrides] allKeys]];
}

- (void)enumerateApplications
{
    NSArray *array = applicationDisplayIdentifiers();
    NSArray *sortedArray = [array sortedArrayUsingFunction:compareDisplayNames context:NULL];
    allApplications = [sortedArray retain];
    [self loadFilteredList];
    [appsTableView reloadData];

    // Remove the progress indicator
    [busyIndicator hide];
    [busyIndicator release];
    busyIndicator = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
    [appsTableView deselectRowAtIndexPath:[appsTableView indexPathForSelectedRow] animated:YES];

    if (allApplications != nil) {
        // Application list already loaded
        [self loadFilteredList];
        [appsTableView reloadData];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    // NOTE: The initial list is loaded after the view appears for style considerations.
    // FIXME: Show busy indicator *before* the view appears.
    if (allApplications == nil) {
        // Show a progress indicator
        busyIndicator = [[UIProgressHUD alloc] initWithWindow:[[UIApplication sharedApplication] keyWindow]];
        [busyIndicator setText:@"Loading applications..."];
        [busyIndicator show:YES];

        // Enumerate applications
        // NOTE: Must call via performSelector, or busy indicator does not show in time
        [self performSelector:@selector(enumerateApplications) withObject:nil afterDelay:0.1f];
    }
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
    }

    cell.displayId = [applications objectAtIndex:indexPath.row];

    return cell;
}

#pragma mark - UITableViewCellDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if ([delegate respondsToSelector:@selector(applicationPickerController:didSelectAppWithDisplayIdentifier:)])
		[delegate applicationPickerController:self didSelectAppWithDisplayIdentifier:[applications objectAtIndex:indexPath.row]];
}

#pragma mark - Navigation-bar button actions

- (void)doneButtonTapped
{
	[self.parentViewController dismissModalViewControllerAnimated:YES];

	if ([delegate respondsToSelector:@selector(applicationPickerControllerDidFinish:)])
		[delegate applicationPickerControllerDidFinish:self];
}

@end

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
