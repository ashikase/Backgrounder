/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-06-21 00:16:38
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


#import "ApplicationCell.h"

#include <dlfcn.h>

// SpringBoardServices
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
extern NSString * SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier);

// Firmware 4.x
// NOTE: The SBS method actually returns CFData; taking advantage of toll-free bridging
static BOOL isFirmware3x = NO;
static NSData * (*SBSCopyIconImagePNGDataForDisplayIdentifier)(NSString *identifier) = NULL;


@implementation ApplicationCell

@synthesize displayId;

+ (void)initialize
{
    // Determine firmware version
    isFirmware3x = [[[UIDevice currentDevice] systemVersion] hasPrefix:@"3"];
    if (!isFirmware3x) {
        // Firmware >= 4.0
        SBSCopyIconImagePNGDataForDisplayIdentifier = dlsym(RTLD_DEFAULT, "SBSCopyIconImagePNGDataForDisplayIdentifier");
    }
}

- (void)setDisplayId:(NSString *)identifier
{
    if (![displayId isEqualToString:identifier]) {
        [displayId release];
        displayId = [identifier copy];

        NSString *displayName = SBSCopyLocalizedApplicationNameForDisplayIdentifier(identifier);
        self.textLabel.text = displayName;
        [displayName release];

        UIImage *icon = nil;
        if (isFirmware3x) {
            // Firmware < 4.0
            NSString *iconPath = SBSCopyIconImagePathForDisplayIdentifier(identifier);
            if (iconPath != nil) {
                icon = [UIImage imageWithContentsOfFile:iconPath];
                [iconPath release];
            }
        } else {
            // Firmware >= 4.0
            if (SBSCopyIconImagePNGDataForDisplayIdentifier != NULL) {
                NSData *data = (*SBSCopyIconImagePNGDataForDisplayIdentifier)(identifier);
                if (data != nil) {
                    icon = [UIImage imageWithData:data];
                    [data release];
                }
            }
        }
        self.imageView.image = icon;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    // Resize icon image
    CGSize size = self.bounds.size;
    self.imageView.frame = CGRectMake(4.0f, 4.0f, size.height - 8.0f, size.height - 8.0f);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

@end

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
