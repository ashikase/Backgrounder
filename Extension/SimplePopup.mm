/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-08-12 01:01:40
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


#import "SimplePopup.h"

#import "Headers.h"


static id $BGAlertItem$initWithTitle$message$(id self, SEL sel, NSString *title, NSString *message)
{
    objc_super $super = {self, objc_getClass("SBAlertItem")};
    self = objc_msgSendSuper(&$super, @selector(init));
    if (self) {
        object_setInstanceVariable(self, "title", reinterpret_cast<void *>([title copy])); 
        object_setInstanceVariable(self, "message", reinterpret_cast<void *>([message copy])); 
    }
    return self;
}

static void $BGAlertItem$dealloc(id self, SEL sel)
{
    NSString *title = nil, *message = nil;
    object_getInstanceVariable(self, "title", reinterpret_cast<void **>(&title));
    object_getInstanceVariable(self, "message", reinterpret_cast<void **>(&message));
    [title release];
    [message release];

    objc_super $super = {self, objc_getClass("SBAlertItem")};
    self = objc_msgSendSuper(&$super, @selector(dealloc));
}

static void $BGAlertItem$configure$requirePasscodeForActions$(id self, SEL sel, BOOL configure, BOOL passcode)
{
    NSString *title = nil, *message = nil;
    object_getInstanceVariable(self, "title", reinterpret_cast<void **>(&title));
    object_getInstanceVariable(self, "message", reinterpret_cast<void **>(&message));
    UIModalView *view = [self alertSheet];
    [view setTitle:title];
    [view setMessage:message];
    [view setNumberOfRows:0];
}

//______________________________________________________________________________
//______________________________________________________________________________

void initSimplePopup()
{
    // Create custom alert-item class
    Class $BGAlertItem = objc_allocateClassPair(objc_getClass("SBAlertItem"), "BackgrounderAlertItem", 0);
    class_addIvar($BGAlertItem, "title", sizeof(id), 0, "@");
    class_addIvar($BGAlertItem, "message", sizeof(id), 0, "@");
    class_addMethod($BGAlertItem, @selector(initWithTitle:message:),
        (IMP)&$BGAlertItem$initWithTitle$message$, "@@:@@");
    class_addMethod($BGAlertItem, @selector(dealloc), (IMP)&$BGAlertItem$dealloc, "v@:");
    class_addMethod($BGAlertItem, @selector(configure:requirePasscodeForActions:),
        (IMP)&$BGAlertItem$configure$requirePasscodeForActions$, "v@:cc");
    objc_registerClassPair($BGAlertItem);
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
