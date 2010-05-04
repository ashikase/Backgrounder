/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-04-23 01:08:00
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


#import "Preferences.h"

#import <notify.h>


@interface Preferences (Private)
- (NSDictionary *)defaults;
@end;

//==============================================================================

@implementation Preferences

@dynamic needsRespring;

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
        // Set default values for options that are not already
        // set in the application's on-disk preferences list.
        [self registerDefaults:[self defaults]];

        // Retain a copy of the initial values of the preferences
        initialValues = [[self dictionaryRepresentation] retain];

        // Create an array to hold requests for respring
        respringRequestors = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [respringRequestors release];
    [initialValues release];
    [super dealloc];
}

- (NSDictionary *)defaults
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"firstRun"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"persistent"];
    [dict setObject:[NSNumber numberWithBool:NO] forKey:@"badgeEnabled"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"badgeEnabledForAll"];

    [dict setObject:[NSArray array] forKey:@"enabledApplications"];

    NSArray *array = [NSArray arrayWithObjects:
        @"com.apple.mobilephone", @"com.apple.mobilemail", @"com.apple.mobilesafari", @"com.apple.mobileipod",
        nil];
    [dict setObject:array forKey:@"blacklistedApplications"];

    return dict;
}

- (NSArray *)keysRequiringRespring
{
    return [NSArray arrayWithObjects:
        kFirstRun, kPersistent, kBadgeEnabled, kBadgeEnabledForAll,
        kEnabledApplications, kBlacklistedApplications,
        nil];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName
{
    // Update the value
    [super setObject:value forKey:defaultName];

    // Immediately write to disk
    [self synchronize];

    // Check if the selected key requires a respring
    if ([[self keysRequiringRespring] containsObject:defaultName]) {
        // Make sure that the value differe from the initial value
        id initialValue = [initialValues objectForKey:defaultName];
        BOOL valuesDiffer = ![value isEqual:initialValue];
        // FIXME: Write to disk, remove on respring
        // FIXME: Show drop down to indicate respring is needed
        if (valuesDiffer) {
            if (![respringRequestors containsObject:defaultName])
                [respringRequestors addObject:defaultName];
        } else {
            [respringRequestors removeObject:defaultName];
        }
    }

    // Send notification that a preference has changed
    notify_post(APP_ID".preferenceChanged");
}

- (BOOL)needsRespring
{
    return ([respringRequestors count] != 0);
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
