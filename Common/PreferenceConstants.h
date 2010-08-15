/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-08-06 00:58:31
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


// Possible values

typedef enum {
    BGBackgroundingMethodOff = 0,
    BGBackgroundingMethodNative,
    BGBackgroundingMethodBackgrounder,
    BGBackgroundingMethodAutoDetect
} BGBackgroundingMethod;


// Preference settings keys

#define kFirstRun                @"firstRun"
#define kCurrentVersion          @"currentVersion"

#define kGlobal                  @"global"
#define kOverrides               @"overrides"

#define kBackgroundingMethod     @"backgroundingMethod"
#define kBadgeEnabled            @"badgeEnabled"
#define kStatusBarIconEnabled    @"statusBarIconEnabled"
#define kPersistent              @"persistent"
#define kEnableAtLaunch          @"enableAtLaunch"
#define kMinimizeOnToggle        @"minimizeOnToggle"
#define kFallbackToNative        @"fallbackToNative"
#define kFastAppSwitchingEnabled @"fastAppSwitchingEnabled"
#define kForceFastAppSwitching   @"forceFastAppSwitching"


// Former preference settings keys

#define kBadgeEnabledForAll      @"badgeEnabledForAll"
#define kBlacklistedApps         @"blacklistedApplications"
#define kEnabledApps             @"enabledApplications"

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
