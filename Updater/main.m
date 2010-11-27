/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-09-29 20:28:41
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


#import "PreferenceConstants.h"

// SpringBoardServices
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);


int main(int argc, char **argv)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Get preferences for all applications
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Get preferences for Backgrounder
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithDictionary:
        [defaults persistentDomainForName:@APP_ID]];
    if ([prefs count] == 0)
        // Preferences do not exist; nothing to convert
        goto exit;

    // Get current version number
    // NOTE: May be non-existant; wasn't added until release r4xx
    int currentVersion = 0;
    id value = [prefs objectForKey:kCurrentVersion];
    if (value != nil && [value isKindOfClass:[NSNumber class]])
        currentVersion = [value intValue];

    if (currentVersion < 432) {
        // Check for existance of no-longer-used preferences
        BOOL needsConversion = NO;
        NSArray *array = [NSArray arrayWithObjects:
            kBadgeEnabled, kBadgeEnabledForAll, kPersistent, kBlacklistedApps, kEnabledApps, nil];
        for (NSString *key in array) {
            if ([prefs objectForKey:key] != nil) {
                needsConversion = YES;
                break;
            }
        }

        if (needsConversion) {
            // Create variables for old settings, set default values
            BOOL badgeEnabled = NO;
            BOOL badgeEnabledForAll = YES;
            BOOL persistent = YES;

            NSArray *blacklistedApps = nil;
            NSArray *enabledApps = nil;

            // Load stored settings, if they exist
            value = [prefs objectForKey:kBadgeEnabled];
            if (value != nil && [value isKindOfClass:[NSNumber class]])
                badgeEnabled = [value boolValue];

            value = [prefs objectForKey:kBadgeEnabledForAll];
            if (value != nil && [value isKindOfClass:[NSNumber class]])
                badgeEnabledForAll = [value boolValue];

            value = [prefs objectForKey:kPersistent];
            if (value != nil && [value isKindOfClass:[NSNumber class]])
                persistent = [value boolValue];

            value = [prefs objectForKey:kBlacklistedApps];
            if (value != nil && [value isKindOfClass:[NSArray class]])
                blacklistedApps = value;

            value = [prefs objectForKey:kEnabledApps];
            if (value != nil && [value isKindOfClass:[NSArray class]])
                enabledApps = value;

            // Create global settings
            NSDictionary *global = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithInteger:BGBackgroundingMethodBackgrounder], kBackgroundingMethod,
                [NSNumber numberWithBool:NO], kEnableAtLaunch,
                [NSNumber numberWithBool:persistent], kPersistent,
                [NSNumber numberWithBool:badgeEnabled], kBadgeEnabled,
                [NSNumber numberWithBool:NO], kStatusBarIconEnabled,
                [NSNumber numberWithBool:YES], kFallbackToNative,
                [NSNumber numberWithBool:YES], kMinimizeOnToggle,
                nil];

            // Create overrides
            NSMutableDictionary *overrides = [NSMutableDictionary dictionary];

            // Add entries for blacklisted applications (use "Native" method)
            for (NSString *displayId in blacklistedApps) {
                NSMutableDictionary *dict = [global mutableCopy];
                [dict setObject:[NSNumber numberWithInteger:BGBackgroundingMethodNative] forKey:kBackgroundingMethod];
                [overrides setObject:dict forKey:displayId];
                [dict release];
            }

            // Add entries for always-enabled applications
            for (NSString *displayId in enabledApps) {
                // Make sure settings for this app do not yet exist
                // NOTE: Technically, always-enabled would have been pointless with blacklisted
                NSMutableDictionary *dict = [overrides objectForKey:displayId];
                if (dict == nil)
                    dict = (NSMutableDictionary *)global;
                dict = [dict mutableCopy];
                [dict setObject:[NSNumber numberWithBool:YES] forKey:kEnableAtLaunch];
                [overrides setObject:dict forKey:displayId];
                [dict release];
            }

            // Delete old settings
            [prefs removeAllObjects];

            // Save the updated preferences
            // NOTE: firstRun will always be NO as preferences existed
            //       (and hence the preferences application had been run)
            [prefs setObject:[NSNumber numberWithBool:NO] forKey:kFirstRun];
            [prefs setObject:global forKey:kGlobal];
            [prefs setObject:overrides forKey:kOverrides];

            // ... and synchronize to disk, replacing old preferences
            [defaults setPersistentDomain:prefs forName:@APP_ID];
            [defaults synchronize];
        }
    }

    if (currentVersion < 461) {
        // Old iPod entry did not include role IDs; fix by adding valid roles
        // NOTE: The role ID check was missing in release 432, causing some people
        //       to end up with invalid iPod settings.

        NSMutableDictionary *overrides = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:kOverrides]];
        NSDictionary *override = [overrides objectForKey:@"com.apple.mobileipod"];
        if (override != nil) {
            [overrides removeObjectForKey:@"com.apple.mobileipod"];

            // List of possible display identifiers
            NSArray *idArray = [NSArray arrayWithObjects:
                @"com.apple.mobileipod-MediaPlayer", @"com.apple.mobileipod-AudioPlayer", @"com.apple.mobileipod-VideoPlayer", nil];

            // Only add overrides for identifiers that are in use on this device
            for (NSString *displayId in idArray) {
                NSString *displayName = SBSCopyLocalizedApplicationNameForDisplayIdentifier(displayId);
                if (displayName != nil) {
                    [overrides setObject:override forKey:displayId];
                    [displayName release];
                }
            }

            // Save the updated preferences
            [prefs setObject:overrides forKey:kOverrides];

            // ... and synchronize to disk, replacing old preferences
            [defaults setPersistentDomain:prefs forName:@APP_ID];
            [defaults synchronize];
        }
    }

    if (currentVersion < 492) {
        // Release 492 introduced support for manual control of "Native".

        // If "Native" method is in use, make sure both "Enable at Launch" and
        // "Stay Enabled" are set to ON.

        // First check global settings
        NSMutableDictionary *global = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:kGlobal]];
        value = [global objectForKey:kBackgroundingMethod];
        if (value != nil && [value isKindOfClass:[NSNumber class]]) {
            if ([value intValue] == BGBackgroundingMethodNative) {
                [global setObject:[NSNumber numberWithBool:YES] forKey:kEnableAtLaunch];
                [global setObject:[NSNumber numberWithBool:YES] forKey:kPersistent];
            }
        }
 
        // Next check each override
        NSMutableDictionary *overrides = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:kOverrides]];
        for (NSString *displayId in [overrides allKeys]) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[overrides objectForKey:displayId]];
            value = [dict objectForKey:kBackgroundingMethod];
            if (value != nil && [value isKindOfClass:[NSNumber class]]) {
                if ([value intValue] == BGBackgroundingMethodNative) {
                    [dict setObject:[NSNumber numberWithBool:YES] forKey:kEnableAtLaunch];
                    [dict setObject:[NSNumber numberWithBool:YES] forKey:kPersistent];

                    [overrides setObject:dict forKey:displayId];
                }
            }
        }

        // Save the updated preferences
        [prefs setObject:global forKey:kGlobal];
        [prefs setObject:overrides forKey:kOverrides];

        // ... and synchronize to disk, replacing old preferences
        [defaults setPersistentDomain:prefs forName:@APP_ID];
        [defaults synchronize];
    }

exit:
    // Update the version number
    [prefs setObject:[NSNumber numberWithInt:CURRENT_VERSION] forKey:kCurrentVersion];

    // ... and synchronize to disk, replacing old preferences
    [defaults setPersistentDomain:prefs forName:@APP_ID];
    [defaults synchronize];

    [pool release];
    return 0;
}

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
