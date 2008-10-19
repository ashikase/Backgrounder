/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-18 22:24:17
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

#import <UIKit/UIKit.h>

#import <UIKit/NSIndexPath-UITableView.h>
@protocol UIActionSheetDelegate;
#import <UIKit/UIActionSheet.h>
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIBezierPath-UIInternal.h>
#import <UIKit/UIFieldEditor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIOldSliderControl.h>
#import <UIKit/UIPreferencesControlTableCell.h>
#import <UIKit/UIPreferencesTextTableCell.h>
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


@interface AboutPage : UIViewController
{
    UIPreferencesTable *table;
}
@end

//______________________________________________________________________________

@implementation AboutPage

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self setTitle:@"About"];
    }
    return self;
}

- (void)loadView
{
#if 0
    PreferencesDataSource *prefSource = [[[PreferencesDataSource alloc] init] retain];
    PreferencesGroup *group;

#if 0
    group = [PreferencesGroup groupWithTitle:@"MobileTerminal" icon:nil];
    [group addValueField:@"Version" value:[NSString stringWithFormat:@"1.0 (%@)", SVN_VERSION]];
    [prefSource addGroup:group];
#endif

    group = [PreferencesGroup groupWithTitle:@"Homepage" icon:nil];
    [group addPageButton:@"code.google.com/p/iphone-backgrounder"];
    [prefSource addGroup:group];

    group = [PreferencesGroup groupWithTitle:@"Contributors" icon:nil];
    [group addValueField:nil value:@"ashikase"];
    [prefSource addGroup:group];

    group = [PreferencesGroup groupWithTitle:@"Acknowledgements" icon:nil];
    [group addValueField:nil value:@"saurik - for Mobile Substrate"];
    [group addValueField:nil value:@"BigBoss - for hosting"];
    [group addValueField:nil value:@"End uers - for feedback and kind words"];
    [prefSource addGroup:group];

    table = [[UIPreferencesTable alloc]
        initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    [table setDataSource:prefSource];
    [table setDelegate:self];
    [table reloadData];
    [self setView:table];
    [table release];
#endif
}

- (void)dealloc
{
#if 0
    [table setDataSource:nil];
    [table setDelegate:nil];
    [table release];
#endif

    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
}

#pragma mark Delegate methods

- (void)tableRowSelected:(NSNotification *)notification
{
#if 0
    if ( [[self view] selectedRow] == 3 )
        [[UIApplication sharedApplication] openURL:
                         [NSURL URLWithString:@"http://code.google.com/p/iphone-backgrounder/"]];
#endif
}

@end

//______________________________________________________________________________
//______________________________________________________________________________

@interface PreferencesPage : UIViewController
{
#if 0
    UIPreferencesTable *table;

    PreferencesGroup *terminalGroup;

    UIPreferencesControlTableCell *shortcutCell[MAX_PAGES];
#else
    UITableView *table;
#endif
}

@end

//______________________________________________________________________________

@implementation PreferencesPage

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self setTitle:@"Backgrounder Prefs"];
        [[self navigationItem] setLeftBarButtonItem:
             [[UIBarButtonItem alloc] initWithTitle:@"Save" style:5
                target:self
                action:@selector(saveButtonClicked)]];
        [[self navigationItem] setBackButtonTitle:@"Back"];
    }
    return self;
}

- (void)loadView
{
#if 0
    PreferencesDataSource *prefSource = [[PreferencesDataSource alloc] init];
    PreferencesGroup *group;

    // ----------------------------------------------------- toggle page buttons
 
#if 0
    group = [PreferencesGroup groupWithTitle:@"Shortcuts" icon:nil];
    for (int i = 0; i < MAX_PAGES; i++) {
        ShortcutConfig *config = [Preferences configForShortcut:i];
        shortcutCell[i] = [group addSwitch:config.name target:self action:@selector(shortcutSwitched:)];
        [[shortcutCell[i] control] setOn:config.enabled];
    }

    [prefSource addGroup:group];
#endif

    // ---------------------------------------------------------- help & credits

    group = [PreferencesGroup groupWithTitle:@"Help" icon:nil];
    [group addPageButton:@"Documentation"];
    [group addPageButton:@"About"];
    [prefSource addGroup:group];

    // -------------------------------------------------------- the table itself

    table = [[UIPreferencesTable alloc]
        initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    [table setDataSource:prefSource];
#else
    table = [[UITableView alloc]
        initWithFrame:[[UIScreen mainScreen] applicationFrame] style:1];
    [table setDataSource:self];
#endif
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

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the table by deselecting the current selection
    [table deselectRowAtIndexPath:[table indexPathForSelectedRow] animated:YES];
}

#pragma mark Delegate methods

- (void)shortcutSwitched:(UISwitch *)control
{
#if 0
    NSLog(@"SuperJumpsPrefs: You toggled a switch!");
    for (int i = 0; i < MAX_PAGES; i++) {
        if (control == [shortcutCell[i] control]) {
            ShortcutConfig *config = [Preferences configForShortcut:i];
            config.enabled = [control isOn];
            break;
        }
    }
#endif
}

- (void)tableRowSelected:(NSNotification *)notification
{
    int row = [[notification object] selectedRow];
    UIPreferencesTableCell *cell = [table cellAtRow:row column:0];
    if (cell) {
        NSString *title = [cell title];
        UIViewController *vc = nil;

#if 0
        if ([title isEqualToString:@"Menu"])
            vc = [[MenuPrefsPage alloc] initWithMenu:nil title:nil];
        else if ([title isEqualToString:@"Gestures"])
            vc = [[GesturePrefsPage alloc] initWithSwipes:0];
        else if ([title isEqualToString:@"Long Swipes"])
            vc = [[GesturePrefsPage alloc]initWithSwipes:1];
        else if ([title isEqualToString:@"Two Finger Swipes"])
            vc = [[GesturePrefsPage alloc]initWithSwipes:2];
        else if ([title isEqualToString:@"About"])
            vc = [[AboutPage alloc] init];
        else {
            // Must be a Terminal cell
            terminalIndex = [[title substringFromIndex:9] intValue] - 1;
            vc = [[TerminalPrefsPage alloc] initWithIndex:terminalIndex];
        }

        if (vc) {
            [[self navigationController] pushViewController:vc animated:YES];
            [vc release];
        }
#endif
    }
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Two sections: "current" and "other" applications
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
            return @"Help";
        default:
            return nil;
    }
    return (section == 0) ? @"Current Application" : @"Other Applications";
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    switch (section) {
        case 0:
            // General
            return 3;
        case 1:
            // Applications
            return 1;
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
            } else if (indexPath.row == 1) {
                [cell setText:@"Feedback type"];
            } else {
                [cell setText:@"Suspend on toggle"];
                [cell setAccessoryType:0];
                [cell setSelectionStyle:0];
                UISwitch *toggle = [[UISwitch alloc] init];
                [toggle setOn:[[Preferences sharedInstance] shouldSuspend]];
                [cell setAccessoryView:toggle];
                [toggle release];
            }
            break;
        case 1:
            // Applications
            [cell setText:@"Enabled at launch"];
            break;
        case 2:
            // Help
            [cell setText:@"Project Homepage"];
            break;
    }

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
#if 0
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1) {
        // Selected a row under "Other applications"

        // Enable backgrounding for current application
        Class $SpringBoard(objc_getClass("SpringBoard"));
        SpringBoard *springBoard = [$SpringBoard sharedApplication];
        [springBoard setBackgroundingEnabled:YES forDisplayIdentifier:[[self alert] currentApp]];

        // Switch to selected application
        Class $SBUIController(objc_getClass("SBUIController"));
        SBUIController *uiCont = [$SBUIController sharedInstance];
        if (indexPath.row == 0) {
            // SpringBoard was selected
            [uiCont quitTopApplication];
        } else {
            NSArray *otherApps = [[self alert] otherApps];
            Class $SpringBoard(objc_getClass("SpringBoard"));
            SpringBoard *sb = [$SpringBoard sharedApplication];
            NSLog(@"Backgrounder: asking to swtich to: %@", [otherApps objectAtIndex:indexPath.row]);
            [sb switchToAppWithDisplayIdentifier:[otherApps objectAtIndex:indexPath.row]];
        }
    }
#else
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
            // Help
            if (indexPath.row == 0)
                // Documentation
                [[UIApplication sharedApplication] openURL:
                                      [NSURL URLWithString:@"http://code.google.com/p/iphone-backgrounder/wiki/Documentation"]];
            else 
                break;
            break;
    }
#endif
}

#pragma mark - Navigation bar delegates

- (void)saveButtonClicked
{
    [[Preferences sharedInstance] writeUserDefaults];
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
        [[UIApplication sharedApplication] terminateWithSuccess];
}

@end

//______________________________________________________________________________
//______________________________________________________________________________

@implementation PreferencesController

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

- (void)viewWillDisappear:(BOOL)animated
{
    // Save the preferences to disk
    [[Preferences sharedInstance] writeUserDefaults];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
