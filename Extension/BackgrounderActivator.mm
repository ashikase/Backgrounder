/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-04-14 02:24:00
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


#import "BackgrounderActivator.h"

#import "SpringBoardHooks.h"

@implementation BackgrounderActivator
 
+ (void)load
{
    static BackgrounderActivator *listener = nil;
    if (listener == nil) {
        LAActivator *activator = [LAActivator sharedInstance];
        if (![activator hasSeenListenerWithName:@APP_ID])
            // Backgrounder has never been assigned an invocation method; set the default
            [activator assignEvent:[LAEvent eventWithName:LAEventNameMenuHoldShort] toListenerWithName:@APP_ID];

        listener = [[BackgrounderActivator alloc] init];
	    [activator registerListener:listener forName:@APP_ID];
    }
}
 
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
    // NOTE: Do not auto dismiss feedback if event is short hold menu/lock button
    //       Auto dismiss simply sends a menu button press; this is not needed
    //       for short hold menu, and causes a screenshot for short hold lock
    BOOL autoSuspend = !([event.name isEqualToString:LAEventNameMenuHoldShort] ||
        [event.name isEqualToString:LAEventNameLockHoldShort]);

    // Invoke Backgrounder
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    [springBoard invokeBackgrounderAndAutoSuspend:autoSuspend];
 
    // Prevent the default OS implementation
    // NOTE: This only prevents the default implementation; it has no effect on
    //       hooks created *after* Activator is loaded.
	event.handled = YES;
}
 
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    [springBoard cancelPreviousBackgrounderInvocation];
}
 
@end

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
