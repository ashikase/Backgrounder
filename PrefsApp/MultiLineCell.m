/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-08-26 00:49:28
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


#import "MultiLineCell.h"

#include <objc/runtime.h>

#define HORIZ_MARGIN 10.0f
#define VERT_MARGIN 11.0f


@implementation MultiLineCell

- (void)setTitle:(NSString *)title
{
    [self setText:title];
    [self setTextAlignment:1]; // Center
}

- (void)setDescription:(NSString *)description
{
    if (description_ == nil) {
        description_ = [[UILabel alloc] initWithFrame:CGRectZero];
        [description_ setFont:[UIFont systemFontOfSize:16.0f]];
        [description_ setTextColor:[UIColor darkGrayColor]];
        [description_ setBackgroundColor:[UIColor whiteColor]];
        [description_ setNumberOfLines:0]; // Limited only by height
        [self.contentView addSubview:description_];
    }

    [description_ setText:description];
}

- (void)setImage:(UIImage *)image
{
    if (image_ != nil) {
        [image_ removeFromSuperview];
        [image_ release];
    }

    image_ = [[UIImageView alloc] initWithImage:image];
    [self.contentView addSubview:image_];
}

- (void)dealloc
{
    [description_ release];
    [image_ release];

    [super dealloc];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect rect;

    UILabel *textLabel = nil;
    UIView *accessoryView = nil;
    object_getInstanceVariable(self, "_textLabel", (void **)&textLabel);
    object_getInstanceVariable(self, "_accessoryView", (void **)&accessoryView);

    if (textLabel) {
        // Adjust the position of the text label (align top)
        rect = [textLabel frame];
        rect.origin.y = VERT_MARGIN;
        [textLabel setFrame:rect];
    }

    if (accessoryView) {
        // Adjust the position of the accessory view (align top)
        rect = [accessoryView frame];
        rect.origin.y = 16.0f;
        [accessoryView setFrame:rect];
    }

    if (image_) {
        // Position the image
        rect = [image_ frame];
        rect.origin.x = HORIZ_MARGIN;
        rect.origin.y = VERT_MARGIN;
        if (textLabel)
            // NOTE: The extra 1 is for the separator
            rect.origin.y += VERT_MARGIN + 1.0f + [textLabel frame].origin.y + [textLabel bounds].size.height;
        [image_ setFrame:rect];
    }

    if (description_) {
        if (image_) {
            // Position the description
            // NOTE: The y position and height will be the same as the image
            rect.origin.x += [image_ frame].origin.x + [image_ bounds].size.width + HORIZ_MARGIN;
            rect.size.width = [self.contentView bounds].size.width - rect.origin.x - HORIZ_MARGIN;
        } else {
            rect = CGRectMake(HORIZ_MARGIN, VERT_MARGIN, [self.contentView bounds].size.width - HORIZ_MARGIN, 44.0f * 3);
            if (textLabel)
                // NOTE: The extra 1 is for the separator
                rect.origin.y += VERT_MARGIN + 1.0f + [textLabel frame].origin.y + [textLabel bounds].size.height;
        }
        [description_ setFrame:rect];
    }

    if (textLabel && (image_ || description_)) {
        // Add a separator
        rect = CGRectMake(HORIZ_MARGIN, 0, 300.0f, 1.0f);
        rect.origin.y = 1.0f + 2 * [textLabel frame].origin.y + [textLabel bounds].size.height;
        UIView *separator = [[UIView alloc] initWithFrame:rect];
        [separator setBackgroundColor:[UIColor grayColor]];
        [self addSubview:separator];
        [separator release];
    }
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
