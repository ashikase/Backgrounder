/**
 * Name: Backgrounder
 * Type: iPhone OS 2.x SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2008-10-21 23:07:53
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

#import "HtmlAlertView.h"

#import <objc/runtime.h>

#import <CoreGraphics/CGGeometry.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <UIKit/UIAlertView-Private.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
typedef struct {} CDAnonymousStruct2;
#import <UIKit/UIGlassButton.h>
#import <UIKit/UILabel.h>
typedef struct {} CDAnonymousStruct14;
#import <UIKit/UITextView.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>


@implementation HtmlAlertView

- (id)initWithString:(NSString *)string title:(NSString *)title_
{
    self = [super init];
    if (self) {
        htmlString = [string copy];
        title = [title_ copy];

        [self setAlertSheetStyle:2];
        [self setDelegate:self];
    }
    return self;
}

- (id)initWithContentsOfFile:(NSString *)filePath title:(NSString *)title_
{
    self = [super init];
    if (self) {
        htmlFilePath = [filePath copy];
        title = [title_ copy];

        [self setAlertSheetStyle:2];
        [self setDelegate:self];
    }
    return self;
}

- (void)willPresentAlertView:(UIAlertView *)alertView
{
    [alertView setBounds:CGRectMake(0, 0, 284, 300)];
    [alertView setCenter:CGPointMake(160, 230)];

    CGSize alertSize = [alertView bounds].size;

    UILabel *titleLabel = nil;
    if (title) {
        // Create a title label
        titleLabel = [[UILabel alloc] initWithFrame:
            CGRectMake(0, 0, alertSize.width, 44)];
        [titleLabel setText:title];
        [titleLabel setTextAlignment:1];
        [titleLabel setFont:[UIFont systemFontOfSize:22.0f]];
        [titleLabel setTextColor:[UIColor whiteColor]];
        [titleLabel setBackgroundColor:[UIColor clearColor]];
        [self addSubview:titleLabel];
        [titleLabel release];
    }
    float titleHeight = (titleLabel) ? 44 : 0;

    // Use a custom button
    float buttonHeight = 44;
    Class $UIGlassButton = objc_getClass("UIGlassButton");
    UIGlassButton *button = [[$UIGlassButton alloc] initWithFrame:CGRectMake(0, 0, alertSize.width - 30, buttonHeight)];
    [button setCenter:CGPointMake(alertSize.width / 2, alertSize.height - buttonHeight / 2)];
    [button setTitle:@"Close" forState:0];
    [button setTintColor:[UIColor colorWithWhite:0.20f alpha:1]];
    [button addTarget:self action:@selector(dismiss) forControlEvents:64];
    [self addSubview:button];
    [button release];

    // Create the HTML view
    UITextView *textView = [[UITextView alloc] initWithFrame:
        CGRectMake(0, titleHeight, alertSize.width, alertSize.height - titleHeight - buttonHeight)];

    NSString *content = nil;
    if (htmlString) {
        content = htmlString;
    } else if (htmlFilePath) {
        NSStringEncoding encoding;
        NSError *error = nil;
        content = [NSString stringWithContentsOfFile:htmlFilePath usedEncoding:&encoding error:&error];
        if (content == nil)
            content = @"<div style=\"text-align:center;\">(404: File not found)</div>";
    }
    [textView setContentToHTMLString:content];
    [textView setTextColor:[UIColor whiteColor]];
    [textView setBackgroundColor:[UIColor clearColor]];
    [textView setFont:[UIFont systemFontOfSize:16.0f]];
    [textView setEditable:NO];
    [textView setMarginTop:0];
    [alertView addSubview:textView];
    [textView release];
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
