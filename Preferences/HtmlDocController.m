/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-04-29 22:06:30
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


#import "HtmlDocController.h"

#import "Constants.h"


static NSString * contentsOfFile(NSString *path, NSString *name)
{
    NSStringEncoding encoding;
    NSError *error = nil;
    return [NSString stringWithContentsOfFile:
        [NSString stringWithFormat:@"%@/%@", path, name]
        usedEncoding:&encoding error:&error];
}

//==============================================================================

@implementation HtmlDocController

@synthesize delegate;

- (id)initWithContentsOfFile:(NSString *)fileName_ templateFile:(NSString *)templateFileName_ title:(NSString *)title
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = title;
        fileName = [fileName_ copy];
        templateFileName = [templateFileName_ copy];

        // NOTE: Using CGRectZero as initial size causes page layout issues
        CGSize size = [[UIScreen mainScreen] applicationFrame].size;
        webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        webView.delegate = self;
        webView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        webView.backgroundColor = [UIColor groupTableViewBackgroundColor];

        // Load the specified file
        // NOTE: Called with a delay parameter so that is executed on the next
        //       event loop, thus allowing this method to return first.
        [self performSelector:@selector(loadFile) withObject:nil afterDelay:0];
    }
    return self;
}

- (void)loadView
{
    if (self.navigationController == nil && self.tabBarController == nil) {
        // Being presented modally; add a title and a dismiss button
 
        // Create a navigation bar
        UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 44.0f)];
        navBar.barStyle = UIBarStyleBlackOpaque;
        navBar.delegate = self;

        // Add title and buttons to navigation bar
        UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:self.title];
        navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Dismiss"
                style:UIBarButtonItemStyleDone target:self action:@selector(dismissButtonTapped)] autorelease];
        [navBar pushNavigationItem:navItem animated:NO];
        [navItem release];

        // Create a view to hold the navigation bar and web view
        UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
        [view addSubview:navBar]; 
        [navBar release];

        // Adjust and add web view
        webView.frame = CGRectMake(0, 44.0f, 320.0f, view.bounds.size.height - 44.0f);
        [view addSubview:webView]; 

        self.view = view;
        [view release];
    } else {
        self.view = webView;
    }
}

- (void)dealloc
{
    [webView release];
    [templateFileName release];
    [fileName release];

    [super dealloc];
}

#pragma mark - File loading methods

- (void)loadFile
{
    NSString *filePath = nil;
    NSString *content = nil;

    if (fileName) {
        // Try loading the specified file
        filePath = [NSString stringWithFormat:@"%@/%@",
                 [[NSBundle mainBundle] bundlePath], @DOC_BUNDLE_PATH];
        content = contentsOfFile(filePath, fileName);

        if (content == nil)
            // Set an error message
            content = @"<div style=\"text-align:center;\">(404: File not found)</div>";
    }

    if (templateFileName) {
        NSString *template = contentsOfFile(filePath, templateFileName);
        if (template) {
            // Escape double-quotes and new-lines
            // FIXME: If content is HTML, not always necessary (will affect attributes)
            content = [content stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            content = [content stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];

            // Add content string to template
            content = [template stringByReplacingOccurrencesOfString:@"<PLACEHOLDER>" withString:content];
        }
    }

    [webView loadHTMLString:content baseURL:[NSURL fileURLWithPath:filePath isDirectory:YES]];
}

#pragma mark - UIWebView delegate methods

- (void)webViewDidFinishLoad:(UIWebView *)webView_
{
    if ([delegate respondsToSelector:@selector(htmlDocControllerDidFinishLoading:)])
        [delegate htmlDocControllerDidFinishLoading:self];
}

- (void)webView:(UIWebView *)webView_ didFailLoadWithError:(NSError *)error
{
    if ([delegate respondsToSelector:@selector(htmlDocControllerDidFailToLoad:)])
        [delegate htmlDocControllerDidFailToLoad:self];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(UIWebViewNavigationType)navigationType
{
    BOOL ret = YES;

    NSURL *url = [request URL];
    if (navigationType == 0 && [[url scheme] hasPrefix: @"http"])
        // http(s) link was clicked, open with external browser
        ret = ![[UIApplication sharedApplication] openURL:url];

    return ret;
}

#pragma mark - UINavigationItem action

- (void)dismissButtonTapped
{
    [self dismissModalViewControllerAnimated:YES];
}

@end

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
