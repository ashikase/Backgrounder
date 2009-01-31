/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-01-31 20:10:14
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


#import "Preferences.h"

#import <Foundation/Foundation.h>


// Allowed values
static NSArray *allowedInvocationMethods = nil;
static NSArray *allowedFeedbackTypes = nil;

@implementation Preferences

@synthesize isModified;
@synthesize firstRun;
@synthesize invocationMethod;
@synthesize feedbackType;
@synthesize enabledApplications;

#pragma mark - Properties

- (void)setInvocationMethod:(unsigned int)method
{
    if (invocationMethod != method) {
        invocationMethod = method;
        isModified = YES;
    }
}

- (void)setFeedbackType:(unsigned int)type
{
    if (feedbackType != type) {
        feedbackType = type;
        isModified = YES;
    }
}

- (void)setEnabledApplications:(NSArray *)apps
{
    if (enabledApplications != apps) {
        [enabledApplications release];
        enabledApplications = [apps retain];
        isModified = YES;
    }
}

#pragma mark - Methods

+ (Preferences *)sharedInstance
{
    static Preferences *instance = nil;
    if (instance == nil)
        instance = [[Preferences alloc] init];
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        allowedInvocationMethods = [[NSArray alloc] initWithObjects:
            @"homeShortPress", @"homeDoubleTap", @"homeSingleTap", nil];
        allowedFeedbackTypes = [[NSArray alloc] initWithObjects:
            @"simplePopup", @"taskMenuPopup", nil];

        [self registerDefaults];
        [self readUserDefaults];
    }
    return self;
}

- (void)dealloc
{
    [enabledApplications release];
    [allowedInvocationMethods release];
    [allowedFeedbackTypes release];
    [super dealloc];
}

- (void)registerDefaults
{
    // NOTE: This method sets default values for options that are not already
    //       already set in the application's on-disk preferences list.

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:4];

    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"firstRun"];
    [dict setObject:@"homeShortPress" forKey:@"invocationMethod"];
    [dict setObject:@"simplePopup" forKey:@"feedbackType"];

    NSArray *array = [NSArray arrayWithObjects:nil];
    [dict setObject:array forKey:@"enabledApplications"];

    [defaults registerDefaults:dict];
}

#pragma mark - Read/Write methods

- (void)readUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    firstRun = [defaults boolForKey:@"firstRun"];

    NSString *prefString = [defaults stringForKey:@"invocationMethod"];
    unsigned int index = [allowedInvocationMethods indexOfObject:prefString];
    invocationMethod = (index == NSNotFound) ? 0 : index;

    prefString = [defaults stringForKey:@"feedbackType"];
    index = [allowedFeedbackTypes indexOfObject:prefString];
    feedbackType = (index == NSNotFound) ? 0 : index;

    enabledApplications = [[defaults arrayForKey:@"enabledApplications"] retain];
}

- (void)writeUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setObject:[NSNumber numberWithBool:firstRun] forKey:@"firstRun"];

    NSString *prefString = nil;
    @try {
        prefString = [allowedInvocationMethods objectAtIndex:invocationMethod];
        if (prefString)
            [defaults setObject:prefString forKey:@"invocationMethod"];
    }
    @catch (NSException *exception) {
        // Ignore the exception (assumed to be NSRangeException)
    }

    @try {
        prefString = [allowedFeedbackTypes objectAtIndex:feedbackType];
        if (prefString)
            [defaults setObject:prefString forKey:@"feedbackType"];
    }
    @catch (NSException *exception) {
        // Ignore the exception (assumed to be NSRangeException)
    }

    [defaults setObject:enabledApplications forKey:@"enabledApplications"];

    [defaults synchronize];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
