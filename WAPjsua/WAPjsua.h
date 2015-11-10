//
//  WAPjsua.h
//  Wakie
//
//  Created by Чингис on 5/14/15.
//  Copyright (c) 2015 WAKIE. All rights reserved.
//

#ifndef __Wakie__WAPjsua__
#define __Wakie__WAPjsua__

#include <stdio.h>

#endif /* defined(__Wakie__WAPjsua__) */

/**
 * Initialize and start pjsua.
 *
 * @param sipUser the sip username to be used for register
 * @param sipDomain the domain of the sip register server
 *
 * @return When successful, returns 0.
 */
int startPjsip(char *sipUser, char* sipDomain, int transportIdx, bool withReg); //0 udp 1 tcp 2 tls

/**
 * Make VoIP call.
 *
 * @param destUri the uri of the receiver, something like "sip:192.168.43.106:5080"
 */
void makeCall(char* destUri);

/**
 * End ongoing VoIP calls
 */
void endCall();

void destroyPjsip();
void setMicEnabled(bool isEnable);

BOOL canStart();

