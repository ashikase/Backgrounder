/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-06-12 03:47:05
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


#import "Preferences.h"

#import <notify.h>

// GraphicsServices
extern CFStringRef kGSUnifiedIPodCapability;
Boolean GSSystemHasCapability(CFStringRef capability);

// SpringBoardServices
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);

//==============================================================================

// Filter out overrides for apps that do not or no longer exist on this device
NSDictionary * filterNotInstalled(NSDictionary *apps)
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:apps];

    for (NSString *displayId in [dict allKeys]) {
        NSString *displayName = SBSCopyLocalizedApplicationNameForDisplayIdentifier(displayId);
        if (displayName == nil)
            // App has no display name; assume not installed
            [dict removeObjectForKey:displayId];
        else
            [displayName release];
    }

    return dict;
}

//==============================================================================

@interface Preferences (Private)
- (NSDictionary *)defaults;
@end;

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

        // Filter out overrides for apps that are no longer installed
        NSDictionary *dict = filterNotInstalled([initialValues objectForKey:kOverrides]);
        [self setObject:dict forKey:kOverrides];
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
    // Read list of default values from disk
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:
        [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];

    // Filter out overrides for apps that do not exist on this device
    // NOTE: Cannot rely on filter in init, as this this method is also called
    //       by resetToDefaults.
    NSDictionary *overDict = filterNotInstalled([dict objectForKey:kOverrides]);

    // Update overrides
    [dict setObject:overDict forKey:kOverrides];

    return dict;
}

- (void)resetToDefaults
{
    // Reset all settings to the default values
    NSDictionary *dict = [self defaults];
    [self setObject:[dict objectForKey:kGlobal] forKey:kGlobal];
    [self setObject:[dict objectForKey:kOverrides] forKey:kOverrides];
}

- (NSArray *)keysRequiringRespring
{
    return [NSArray arrayWithObjects:kGlobal, kOverrides, nil];
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

#pragma mark - Value retrieval methods

- (id)objectForKey:(NSString *)defaultName forDisplayIdentifier:(NSString *)displayId
{
    NSDictionary *dict = nil;
    if (displayId != nil) {
        // Retrieve settings for the specified application
        dict = [[self objectForKey:kOverrides] objectForKey:displayId];
        if (dict == nil)
            // Settings do not exist; use global settings
            dict = [self objectForKey:kGlobal];
    } else {
        // Retrieve global settings
        dict = [self objectForKey:kGlobal];
    }

    // Retrieve the value for the specified key
    id value = [dict objectForKey:defaultName];
    if (value == nil)
        // Key may not have existed in previous version; check default global values
        value = [[[self defaults] objectForKey:kGlobal] objectForKey:defaultName];

    return value;
}

- (BOOL)boolForKey:(NSString *)defaultName forDisplayIdentifier:(NSString *)displayId
{
    BOOL ret = NO;

    id value = [self objectForKey:defaultName forDisplayIdentifier:displayId];
    if ([value isKindOfClass:[NSNumber class]])
        ret = [value boolValue];

    return ret;
}

- (NSInteger)integerForKey:(NSString *)defaultName forDisplayIdentifier:(NSString *)displayId
{
    NSInteger ret = 0;

    id value = [self objectForKey:defaultName forDisplayIdentifier:displayId];
    if ([value isKindOfClass:[NSNumber class]])
        ret = [value integerValue];

    return ret;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName forDisplayIdentifier:(NSString *)displayId
{
    NSMutableDictionary *dict = nil;
    if (displayId != nil) {
        // Retrieve settings for the specified application
        dict = [[self objectForKey:kOverrides] objectForKey:displayId];
        if (dict == nil)
            // Settings do not exist; copy global settings
            dict = [self objectForKey:kGlobal];

        // Create mutable copy
        dict = [NSMutableDictionary dictionaryWithDictionary:dict];

        // Store the value
        [dict setObject:value forKey:defaultName];

        // Store application settings back to overrides
        NSMutableDictionary *overDict = [NSMutableDictionary dictionaryWithDictionary:[self objectForKey:kOverrides]];
        [overDict setObject:dict forKey:displayId];

        // Store overrides
        [self setObject:overDict forKey:kOverrides];
    } else {
        // Retrieve global settings
        // NOTE: While it should not happen, simply calling mutableCopy on the
        //       result of objectForKey: could lead to a nil dictionary.
        //       This also applies to other mutable copies used in this method.
        dict = [NSMutableDictionary dictionaryWithDictionary:[self objectForKey:kGlobal]];

        // Store the value
        [dict setObject:value forKey:defaultName];

        // Store the global settings
        [self setObject:dict forKey:kGlobal];
    }
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName forDisplayIdentifier:(NSString *)displayId
{
    [self setObject:[NSNumber numberWithBool:value] forKey:defaultName forDisplayIdentifier:displayId];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName forDisplayIdentifier:(NSString *)displayId
{
    [self setObject:[NSNumber numberWithInteger:value] forKey:defaultName forDisplayIdentifier:displayId];
}

#pragma mark - Overrides methods

- (void)addOverrideForDisplayId:(NSString *)displayId
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self objectForKey:kOverrides]];
    [dict setObject:[self objectForKey:kGlobal] forKey:displayId];
    [self setObject:dict forKey:kOverrides];
}

- (void)removeOverrideForDisplayId:(NSString *)displayId
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self objectForKey:kOverrides]];
    [dict removeObjectForKey:displayId];
    [self setObject:dict forKey:kOverrides];
}

@end

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
