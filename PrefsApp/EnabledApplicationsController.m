/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-19 22:22:08
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

#import "EnabledApplicationsController.h"

#import <objc/runtime.h>

#import <CoreGraphics/CGGeometry.h>
#import <QuartzCore/CALayer.h>

#import <CoreFoundation/CFPreferences.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSString.h>

#import <UIKit/NSIndexPath-UITableView.h>
@protocol UIAlertViewDelegate;
typedef struct {} CDAnonymousStruct7;
#import <UIKit/UIAlertView.h>
#import <UIKit/UIAlertView-Private.h>
typedef struct {} CDAnonymousStruct2;
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIImage-UIImageInternal.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UINavigationItem.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UISwitch.h>
@protocol UITableViewDataSource;
#import <UIKit/UITableView.h>
#import <UIKit/UITableViewCell.h>
typedef struct {} CDAnonymousStruct14;
#import <UIKit/UITextView.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>
#import <UIKit/UIViewController-UINavigationControllerItem.h>

extern int SBSSpringBoardServerPort();
//extern int SBApplicationDisplayIdentifiers(int, unsigned short, unsigned short, char **);
extern int SBLocalizedApplicationNameForDisplayIdentifier(int, const char *, char *, int);
extern int SBIconImagePathForDisplayIdentifier(int, const char *, char *, int);


static NSMutableArray *displayIdentifiers = nil;

static void loadIdentifiersFromList(NSDictionary *list)
{
    NSArray *iconMatrix = [list objectForKey:@"iconMatrix"];
    for (NSArray *row in iconMatrix)
        for (id entry in row) {
            //NSLog(@"Backgrounder: row: %s, %@", object_getClassName(entry), entry);
            if ([entry isKindOfClass:[NSDictionary class]]) {
                NSString *identifier = [entry objectForKey:@"displayIdentifier"];
                if (identifier) {
                    // Check if identifier is a UUID (and thus a webclip)
                    NSArray *comp = [identifier componentsSeparatedByString:@"-"];
                    if ([comp count] != 5)
                        [displayIdentifiers addObject:identifier];
                }
            }
        }
}

static NSInteger compareDisplayNames(NSString *a, NSString *b, void *context)
{
    char buf_a[1024] = {0}, buf_b[1024] = {0};;

    int port = SBSSpringBoardServerPort();
    (void)SBLocalizedApplicationNameForDisplayIdentifier(port, [a UTF8String], buf_a, 1024);
    (void)SBLocalizedApplicationNameForDisplayIdentifier(port, [b UTF8String], buf_b, 1024);

    int ret = strcasecmp(buf_a, buf_b);
    if (ret > 0)
        return NSOrderedDescending;
    else if (ret < 0)
        return NSOrderedAscending;
    else
        return NSOrderedSame;
}

@interface HtmlAlertView : UIAlertView
@end

@implementation HtmlAlertView

- (id)initWithTitle:(NSString *)title htmlBody:(NSString *)htmlBody
{
    self = [super init];
    if (self) {
        [self setTitle:title];
        [self addButtonWithTitle:@"Close"];
        [self setCancelButtonIndex:0];

        UITextView *textView = [[UITextView alloc] initWithFrame:
            CGRectMake(0, 0, 200, 200)];
        [textView setContentToHTMLString:htmlBody];
        [textView sizeToFit];
        NSLog(@"Backgrounder: title width: %f, height: %f", [textView bounds].size.width, [textView bounds].size.height);
        [textView setTextColor:[UIColor whiteColor]];
        [textView setBackgroundColor:[UIColor clearColor]];
        [self addSubview:textView];
        [textView release];

        Ivar ivar = class_getInstanceVariable([self class], "_bodyTextHeight");
        float *bodyTextHeight = (float *)((char *)self + ivar_getOffset(ivar));
        *bodyTextHeight = 200.0f;
    }
    return self;
}

@end

@implementation EnabledApplicationsController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self setTitle:@"Enabled Apps"];
        [[self navigationItem] setRightBarButtonItem:
             [[UIBarButtonItem alloc] initWithTitle:@"Help" style:5
                target:self
                action:@selector(helpButtonTapped)]];

        // Enumerate applications
        displayIdentifiers = [[NSMutableArray alloc] initWithCapacity:20];
        CFPropertyListRef iconState = CFPreferencesCopyAppValue(CFSTR("iconState"), CFSTR("com.apple.springboard"));
        id dock = [(NSDictionary *)iconState objectForKey:@"buttonBar"];
        loadIdentifiersFromList(dock);
        id iconLists = [(NSDictionary *)iconState objectForKey:@"iconLists"];
        for (id list in iconLists)
            loadIdentifiersFromList(list);
        [displayIdentifiers sortUsingFunction:compareDisplayNames context:NULL];
#if 0
        char **buf = NULL;
        int port = SBSSpringBoardServerPort();
        int ret = SBApplicationDisplayIdentifiers(port, 10, 10, buf);
        NSLog(@"Backgrounder: RETURN val: %d", ret);
#endif
    }
    return self;
}

- (void)loadView
{
    table = [[UITableView alloc]
        initWithFrame:[[UIScreen mainScreen] applicationFrame] style:1];
    [table setDataSource:self];
    [table setDelegate:self];
    [table reloadData];
    [self setView:table];
}

- (void)dealloc
{
    [table setDataSource:nil];
    [table setDelegate:nil];
    [table release];

    [displayIdentifiers release];

    [super dealloc];
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
    return [displayIdentifiers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"EnabledApplicationsCell";

    // Try to retrieve from the table view a now-unused cell with the given identifier
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil)
        // Cell does not exist, create a new one
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:reuseIdentifier] autorelease];

    int port = SBSSpringBoardServerPort();

    const char *identifier = [[displayIdentifiers objectAtIndex:indexPath.row] UTF8String];
    char buf[1024] = {0};

    int ret = SBLocalizedApplicationNameForDisplayIdentifier(port, identifier, buf, 1024);
    if (ret == 0)
        [cell setText:[NSString stringWithUTF8String:buf]];

    ret = SBIconImagePathForDisplayIdentifier(port, identifier, buf, 1024);
    if (ret == 0) {
        UIImage *icon = [UIImage imageWithContentsOfFile:[NSString stringWithUTF8String:buf]];
        icon = [icon _imageScaledToSize:CGSizeMake(35, 36) interpolationQuality:0];
        [cell setImage:icon];
    }

    UISwitch *toggle = [[UISwitch alloc] init];
    //[toggle setOn:[[Preferences sharedInstance] shouldSuspend]];
    [cell setAccessoryView:toggle];
    [toggle release];

    return cell;
}

#pragma mark - UITableViewCellDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[self navigationController] popToRootViewControllerAnimated:YES];
}

#pragma mark - Navigation bar delegates

- (void)helpButtonTapped
{
#if 0
    UIAlertView *alert = [[[UIAlertView alloc]
        initWithTitle:@"Help" message:nil
             delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil] autorelease];
#endif
    //UIAlertView *alert = [[[UIAlertView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)] autorelease];
    HtmlAlertView *alert = [[[HtmlAlertView alloc]
        initWithTitle:@"Explanation"
        htmlBody:@"This is some<br/>Neat stuff"] autorelease];
//"Normally, backgrounding must be enabled manually for every new instance of an application. By selecting enabling an application on this screen (by setting its switch to ON), that application will automatically have backgrounding enabled upon launch."
    [alert show];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
