/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-08-26 00:49:31
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


#import "DocumentationController.h"

#import <UIKit/UIViewController-UINavigationControllerItem.h>

#import "Constants.h"


@implementation DocumentationController

- (id)initWithContentsOfFile:(NSString *)fileName_ title:(NSString *)title
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        fileName = [fileName_ copy];

        [self setTitle:title];
#if 0
        [[self navigationItem] setRightBarButtonItem:
             [[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:5
                target:self
                action:@selector(loadRemoteFile)]];
#endif
    }
    return self;
}

- (void)loadView
{
    CGRect frame = [[UIScreen mainScreen] applicationFrame];

    UIView *view = [[UIView alloc] initWithFrame:frame];
    [view setBackgroundColor:[UIColor groupTableViewBackgroundColor]];

    webView = [[UIWebView alloc] initWithFrame:[view bounds]];
    [webView setAutoresizingMask:(1 << 4)]; // UIViewAutoresizingFlexibleHeight;
    [webView setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    [webView setDelegate:self];
    [webView setHidden:YES];
    [view addSubview:webView];

    [self setView:view];
    [view release];
}

- (void)dealloc
{
    [webView release];
    [fileName release];

    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self loadLocalFile];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView_
{
    [webView_ setHidden:NO];
}

- (void)webView:(UIWebView *)webView_ didFailLoadWithError:(NSError *)error
{
    // FIXME: Should handle this somehow, perhaps display an error popup?
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(int)navigationType
{
    BOOL ret = YES;

    NSURL *url = [request URL];
    if (navigationType == 0 && [[url scheme] hasPrefix: @"http"])
        // http(s) link was clicked, open with external browser
        ret = ![[UIApplication sharedApplication] openURL:url];

    return ret;
}

#pragma mark - File loading methods

static NSString * contentsOfFile(NSString *path, NSString *name)
{
    NSStringEncoding encoding;
    NSError *error = nil;
    return [NSString stringWithContentsOfFile:
        [NSString stringWithFormat:@"%@/%@", path, name]
        usedEncoding:&encoding error:&error];
}

- (void)loadLocalFile
{
    NSString *filePath = nil;
    NSString *content = nil;

    if (fileName) {
        // Try loading a previously-downloaded version of the file
        filePath = @DOC_CACHE_PATH;
        content = contentsOfFile(filePath, fileName);

        if (content == nil) {
            // Try loading the version of the file included in the install package
            filePath = [NSString stringWithFormat:@"%@/%@",
                     [[NSBundle mainBundle] bundlePath], @DOC_BUNDLE_PATH];
            content = contentsOfFile(filePath, fileName);

            if (content == nil)
                // Set an error message
                content = @"<div style=\"text-align:center;\">(404: File not found)</div>";
        }
    }

    [webView loadHTMLString:content baseURL:[NSURL fileURLWithPath:filePath isDirectory:YES]];
}

- (void)loadRemoteFile
{
    NSError *error = nil;
    NSHTTPURLResponse *response = nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:
        [NSString stringWithFormat:@"%@/%@", @DOC_URL, fileName]]];
    NSData *data = [NSURLConnection sendSynchronousRequest:request
        returningResponse:&response error:&error];
  
    NSLog(@"Response status: %ld, %@", (long)[response statusCode],
        [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]]);
    if (data) {
        // Display in webview
        [webView loadData:data MIMEType:@"text/html" textEncodingName:@"UTF-8" baseURL:
     [NSURL URLWithString:@DOC_URL]];

        // Save to local cache
    }
}

@end

/* vim: set syntax=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
