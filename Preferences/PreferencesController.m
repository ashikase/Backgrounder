/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-08-17 20:37:34
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

#import <QuartzCore/QuartzCore.h>

#import "Constants.h"
#import "HtmlDocController.h"
#import "Preferences.h"
#import "ToggleButton.h"

extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);

static BOOL isFirmware3x_ = NO;

@interface PreferencesController (Private)
- (void)updateSectionVisibility;
- (UIView *)tableHeaderView;
@end

@implementation PreferencesController

+ (void)initialize
{
    // Determine firmware version
    isFirmware3x_ = [[[UIDevice currentDevice] systemVersion] hasPrefix:@"3"];
}

- (id)initWithDisplayIdentifier:(NSString *)displayId
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        displayIdentifier = [displayId copy];

        self.title = (displayId == nil) ? @"Global Settings" :
            [SBSCopyLocalizedApplicationNameForDisplayIdentifier(displayId) autorelease];

        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil];

        self.tableView.tableHeaderView = [self tableHeaderView];

        // Retrieve current value for backgrounding method
        Preferences *prefs = [Preferences sharedInstance];
        backgroundingMethod = (BGBackgroundingMethod)
            [prefs integerForKey:kBackgroundingMethod forDisplayIdentifier:displayIdentifier];

        // Retrieve current value of "Even if Unsupported" option
        showEvenIfUnsupported = 
            [prefs boolForKey:kFastAppSwitchingEnabled forDisplayIdentifier:displayIdentifier];

        // Determine initial visibility flags and offset
        [self updateSectionVisibility];
    }
    return self;
}

- (void)dealloc
{
    [displayIdentifier release];
    [super dealloc];
}

#pragma mark - Miscellaneous

- (void)updateSectionVisibility
{
    // Update section visibility flags
    showBackgrounderOptions = (backgroundingMethod == BGBackgroundingMethodBackgrounder);
    showNativeOptions = !isFirmware3x_
        && ((backgroundingMethod == BGBackgroundingMethodNative)
        || (showBackgrounderOptions && [[Preferences sharedInstance]
                boolForKey:kFallbackToNative forDisplayIdentifier:displayIdentifier]));

    // Update the section offset
    sectionOffset = !showNativeOptions + !showBackgrounderOptions;
}

- (UIView *)tableHeaderView
{
    // Determine size of application frame (iPad, iPhone differ)
    CGRect appFrame = [[UIScreen mainScreen] applicationFrame];

    // Create table header
    UIView *view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, appFrame.size.width, 60.0f)] autorelease];

    // Create label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = (displayIdentifier == nil) ?
        @"These settings will apply to all apps,\nexcept those with overrides." :
        [@"These settings will apply only to\n" stringByAppendingString:self.title];

    label.numberOfLines = 2;
    label.textColor = [UIColor whiteColor];
    label.textAlignment = UITextAlignmentCenter;
    label.backgroundColor = [UIColor colorWithRed:0.35f green:0.36f blue:0.38f alpha:1.0f];
    label.layer.cornerRadius = 5.0f;
    label.layer.borderColor = [[UIColor blackColor] CGColor];
    label.layer.borderWidth = 1.0f;

    // Resize label to fit text
    // NOTE: Add 10 pixels to each dimension for padding.
    const float height = 40.0f + 10.0f;
    CGSize size = [label.text sizeWithFont:label.font constrainedToSize:CGSizeMake(CGFLOAT_MAX, height)
        lineBreakMode:UILineBreakModeWordWrap];
    float width = size.width + 10.0f;
    label.frame = CGRectMake((appFrame.size.width - width) / 2.0f, 10.0f, width, height);

    [view addSubview:label];
    [label release];

    return view;
}

#pragma mark - UITableViewDataSource

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (backgroundingMethod == BGBackgroundingMethodOff) ? 1 : 6 - sectionOffset;
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section
{
    static int rows[] = {4, 2, 1, 2, 2, 1};

    // Adjust section based on visibility of Native/Backgrounder options
    if (section > 1 || (section == 1 && !showNativeOptions))
        section += sectionOffset;

    // Get number of rows for requested section
    int ret = rows[section];
    if (section == 0) {
        if (isFirmware3x_)
            // Don't show Auto Detect method
            ret--;
    } else if (section == 1 && showNativeOptions) {
        // Adjust number of rows in Native options section
        ret -= !showEvenIfUnsupported;
    }

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdToggle = @"ToggleCell";
    static NSString *reuseIdSimple = @"SimpleCell";

    static NSString *cellTitles[][4] = {
        {@"Off", @"Native", @"Backgrounder", @"Auto Detect"},
        {@"Fast App Switching", @"\u21b3 Even if Unsupported", nil, nil},
        {@"Fall Back to Native", nil, nil, nil},
        {@"Enable at Launch", @"Stay Enabled", nil, nil},
        {@"Badge", @"Status Bar Icon", nil, nil},
        {@"Minimize on Toggle", nil, nil, nil}
    };
    static NSString *cellSubtitles[][4] = {
        {@"App will quit when minimized", @"Use native method, if supported",
            @"Run as if in foreground", @"Native if supported, else Backgrounder"},
        {@"Keep apps paused in memory", @"Include apps not updated for iOS4", nil, nil},
        {@"If state disabled, use native method", nil, nil, nil},
        {@"No need to manually enable", @"Must be disabled manually", nil, nil},
        {@"Mark the app's icon", @"Mark the app's status bar", nil, nil},
        {@"Minimize app when toggling state", nil, nil, nil}
    };
    static NSString *methodImages[] = {
        @"method_off.png", @"method_native.png", @"method_backgrounder.png", @"method_autodetect.png"
    };

    int offset = 0;

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

        // Set image for cell
        cell.imageView.image = [UIImage imageNamed:methodImages[indexPath.row]];
    } else {
        // Backgrounding indicators, Other
        static NSString *keys[][2] = {
            {kFastAppSwitchingEnabled, kForceFastAppSwitching},
            {kFallbackToNative, nil},
            {kEnableAtLaunch, kPersistent},
            {kBadgeEnabled, kStatusBarIconEnabled},
            {kMinimizeOnToggle, nil}};

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

        // Determine the section offset
        offset = (indexPath.section == 1 && showNativeOptions) ? 0 : sectionOffset;

        UIButton *button = (UIButton *)cell.accessoryView;
        Preferences *prefs = [Preferences sharedInstance];
        button.selected = [prefs boolForKey:keys[(indexPath.section - 1) + offset][indexPath.row] forDisplayIdentifier:displayIdentifier];

        // Set image for cell
        cell.imageView.image = (indexPath.section == 4) ?
            [UIImage imageNamed:((indexPath.row == 0) ? @"badge.png" : @"status_bar_icon.png")] :
            nil;
    }

    cell.textLabel.text = cellTitles[indexPath.section + offset][indexPath.row];
    cell.detailTextLabel.text = cellSubtitles[indexPath.section + offset][indexPath.row];

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
    static NSString *titles[] = {
        @"Backgrounding method",
        @"Options for \"Native\"", @"Options for \"Backgrounder\"",
        @"Backgrounding state", @"Indicate state via...", @"Miscellaneous",
    };

    // Adjust section based on visibility of Native/Backgrounder options
    if (section > 1 || (section == 1 && !showNativeOptions))
        section += sectionOffset;

    // Determine size of application frame (iPad, iPhone differ)
    CGRect appFrame = [[UIScreen mainScreen] applicationFrame];

    // Determine offsets
    float topOffset = (section == 0) ? 10.0f : 0;
    float indent = (appFrame.size.width == 320.0f) ? 19.0f : 54.0f;

    // Create a container view for the header
    UIView *view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0.0f, appFrame.size.width, 36.0f + topOffset)] autorelease];;

    // Create the text label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(indent, 7.0f + topOffset, appFrame.size.width - indent, 21.0f)];
    label.font = [UIFont boldSystemFontOfSize:17.0f];
    label.text = titles[section];
    label.textColor = [UIColor colorWithRed:0.3f green:0.34f blue:0.42f alpha:1.0f];
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(1.0, 1.0f);
    [view addSubview:label];

    // Create the info button
    UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoDark];
    button.center = CGPointMake(view.bounds.size.width - button.bounds.size.width / 2.0f - indent - 1.0f, label.center.y);
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
        if (indexPath.row  != (int)backgroundingMethod) {
            // Method has changed; cache previous values
            BGBackgroundingMethod prevMethod = backgroundingMethod;
            BOOL nativeOptionsWasShown = showNativeOptions;
            BOOL backgrounderOptionsWasShown = showBackgrounderOptions;

            // Update cached backgrounding method value
            backgroundingMethod = (BGBackgroundingMethod)indexPath.row;

            // Update visibility flags and offset
            [self updateSectionVisibility];

            // Store the new method
            Preferences *prefs = [Preferences sharedInstance];
            [prefs setInteger:backgroundingMethod forKey:kBackgroundingMethod forDisplayIdentifier:displayIdentifier];

            if (backgroundingMethod == BGBackgroundingMethodNative) {
                // "Native" backgrounding method selected; set certain other options
                // NOTE: This is done so that, by default, app will behave the same
                // as it would if Backgrounder were not installed.
                [prefs setBool:YES forKey:kEnableAtLaunch forDisplayIdentifier:displayIdentifier];
                [prefs setBool:YES forKey:kPersistent forDisplayIdentifier:displayIdentifier];
            }

            // Determine which table sections to show/hide
            NSMutableIndexSet *indexesToInsert = [NSMutableIndexSet indexSet];
            NSMutableIndexSet *indexesToDelete = [NSMutableIndexSet indexSet];
            if (prevMethod == BGBackgroundingMethodOff) {
                // Backgrounding method was Off, readd sections
                [indexesToInsert addIndexesInRange:NSMakeRange(1, showNativeOptions + showBackgrounderOptions + 3)];
            } else {
                // FIXME: Any way to clean up/simplify this code?
                switch (backgroundingMethod) {
                    case BGBackgroundingMethodOff:
                        // Backgrounding method is Off; remove all but first section
                        [indexesToDelete addIndexesInRange:NSMakeRange(1, nativeOptionsWasShown + backgrounderOptionsWasShown + 3)];
                        break;
                    case BGBackgroundingMethodNative:
                        if (backgrounderOptionsWasShown) {
                            if (nativeOptionsWasShown) {
                                // NOTE: Native options already shown
                                [indexesToDelete addIndex:2];
                                break;
                            } else {
                                [indexesToDelete addIndex:1];
                            }
                        }

                        if (showNativeOptions)
                            // Show Native options
                            [indexesToInsert addIndex:1];

                        break;
                    case BGBackgroundingMethodBackgrounder:
                        if (showNativeOptions) {
                            // Show Backgrounder options
                            [indexesToInsert addIndex:2];

                            // Show Native options
                            if (!nativeOptionsWasShown)
                                [indexesToInsert addIndex:1];
                        } else {
                            // Show Backgrounder options
                            [indexesToInsert addIndex:1];

                            // Hide Native options
                            if (nativeOptionsWasShown)
                                [indexesToDelete addIndex:1];
                        }
                        break;
                    case BGBackgroundingMethodAutoDetect:
                        // Hide Native/Backgrounder options
                        [indexesToDelete addIndexesInRange:NSMakeRange(1, nativeOptionsWasShown + backgrounderOptionsWasShown)];
                        break;
                    default:
                        break;
                }
            }

            // Update the table
            [tableView beginUpdates];
            if ([indexesToDelete count] != 0)
                [tableView deleteSections:indexesToDelete withRowAnimation:UITableViewRowAnimationFade];
            if ([indexesToInsert count] != 0)
                [tableView insertSections:indexesToInsert withRowAnimation:UITableViewRowAnimationFade];
            [tableView endUpdates];

            // Must reload first section to update selected method checkmark
            NSIndexSet *indexesToReload = [NSIndexSet indexSetWithIndex:0];
            [tableView reloadSections:indexesToReload withRowAnimation:UITableViewRowAnimationNone];
        }

        // Deselect the selected row
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - UIButton delegate

- (void)buttonToggled:(UIButton *)button
{
    static NSString *keys[][2] = {
        {kFastAppSwitchingEnabled, kForceFastAppSwitching},
        {kFallbackToNative, nil},
        {kEnableAtLaunch, kPersistent},
        {kBadgeEnabled, kStatusBarIconEnabled},
        {kMinimizeOnToggle, nil}};

    // Update selected state of button
    button.selected = !button.selected;

    // Update preference
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)[button superview]];
    int offset = (indexPath.section == 1 && showNativeOptions) ? 0 : sectionOffset;
    NSString *key = keys[(indexPath.section - 1) + offset][indexPath.row];
    [[Preferences sharedInstance] setBool:button.selected forKey:key forDisplayIdentifier:displayIdentifier];

    if (!isFirmware3x_) {
        if ([key isEqualToString:kFastAppSwitchingEnabled]) {
            // Visibility of "Even if Unsupported" is changing

            // Cache the updated value
            showEvenIfUnsupported = button.selected;

            // Update the table
            UITableView *tableView = self.tableView;
            NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:1]];

            [tableView beginUpdates];
            if (showEvenIfUnsupported)
                // Show the "Even if Unsupported" option
                [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
            else
                // Hide the "Even if Unsupported" option
                [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
            [tableView endUpdates];
        } else if ([key isEqualToString:kFallbackToNative]) {
            // Visibility of Native options is changing; update visible sections
            [self updateSectionVisibility];

            // Update the table
            UITableView *tableView = self.tableView;
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:1];

            [tableView beginUpdates];
            if (showNativeOptions)
                // Show the Native options
                [tableView insertSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
            else
                // Hide the Native options
                [tableView deleteSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
            [tableView endUpdates];
        }
    }
}

#pragma mark - Navigation bar delegates

- (void)helpButtonTapped:(UIButton *)sender
{
    static NSString *helpFiles[] = {
        nil, @"help_options_native.mdwn", @"help_options_backgrounder.mdwn",
        @"help_state.mdwn", @"help_indicators.mdwn", @"help_misc.mdwn"};

    // Provide different documentation for "Backgrounding method", depending on firmware version.
    // FIXME: Find a cleaner way to do this.
    int index = sender.tag;
    NSString *helpFile = nil;
    if (index == 0)
        helpFile = isFirmware3x_ ? @"help_method_3x.mdwn" : @"help_method_4x.mdwn";
    else
        helpFile = helpFiles[index];

    // Create and show help page
    // NOTE: Controller is released in delegate callback
    HtmlDocController *docCont = [[HtmlDocController alloc]
        initWithContentsOfFile:helpFile templateFile:@"template.html" title:@"Help"];
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
