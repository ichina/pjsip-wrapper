//
//  WAPjsua.c
//  Wakie
//
//  Created by Чингис on 5/14/15.
//  Copyright (c) 2015 WAKIE. All rights reserved.
//

#include "WAPjsua.h"

#include <pjsua-lib/pjsua.h>

#define THIS_FILE "XCPjsua.c"
static pjsua_acc_id acc_id;
extern pj_bool_t pjsip_use_compact_form;

// enable compact form


const size_t MAX_SIP_ID_LENGTH = 50;
const size_t MAX_SIP_REG_URI_LENGTH = 50;

static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata);
static void on_call_state(pjsua_call_id call_id, pjsip_event *e);
static void on_call_media_state(pjsua_call_id call_id);
static void logs_cb(int level, const char *data, int len);

//registration callbacks
static void on_reg_started(pjsua_acc_id acc_id, pj_bool_t renew);
static void on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info *info);


static void error_exit(const char *title, pj_status_t status);

int startPjsip(char *sipUser, char* sipDomain, int transportIdx, bool withReg)
{
    if(!canStart()) {
        error_exit("core already started", 0);
        return 1;
    }
    
    pj_status_t status;
    pjsua_transport_id tid;
    // Create pjsua first
    status = pjsua_create();
    if (status != PJ_SUCCESS) error_exit("Error in pjsua_create()", status);
    
    // Init pjsua
    {
        // Init the config structure
        pjsua_config cfg;
        pjsua_config_default (&cfg);
        
        cfg.cb.on_incoming_call = &on_incoming_call;
        cfg.cb.on_call_media_state = &on_call_media_state;
        cfg.cb.on_call_state = &on_call_state;
        cfg.cb.on_reg_state2 = &on_reg_state2;
        cfg.cb.on_reg_started = &on_reg_started;

        // Init the logging config structure
        pjsua_logging_config log_cfg;
        pjsua_logging_config_default(&log_cfg);
        log_cfg.console_level = 4;
        log_cfg.cb = &logs_cb;
        
        pjsua_media_config media_cfg;
        pjsua_media_config_default(&media_cfg);
        media_cfg.no_vad = 0;
        
        // Init the pjsua
        status = pjsua_init(&cfg, &log_cfg, &media_cfg);
        if (status != PJ_SUCCESS) error_exit("Error in pjsua_init()", status);
    
        
        pj_str_t codec_id = pj_str( "opus/48000" );
        
        if ( pjsua_codec_set_priority( &codec_id, PJMEDIA_CODEC_PRIO_HIGHEST ) != PJ_SUCCESS )
        {
            fprintf(stderr, "Warning: Failed to set opus/48000 codec at highest priority\n" );
        }
        pjsua_codec_info c[32];
        
        unsigned k, count = PJ_ARRAY_SIZE(c);
        
        printf("List of audio codecs:\n");
        
        pjsua_enum_codecs(c, &count);
        
        for (k=0; k<count; ++k) {
            
            printf("  %d\t%.*s\n", c[k].priority, (int)c[k].codec_id.slen,
                   
                   c[k].codec_id.ptr);
            
        }
    }
    
    @try {
        
        
        // Add UDP transport.
        {
            // Init transport config structure
            pjsua_transport_config cfg;
            pjsua_transport_config_default(&cfg);
            cfg.port = 5060;
            
            // Add UDP transport.
            status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &cfg, &tid);
            if (status != PJ_SUCCESS)
                error_exit("Error creating transport", status);
        }
        
        
        // Add TCP transport.
        if(transportIdx>0)
        {
            if(transportIdx == 1 || [[NSString platformType] rangeOfString:@"Simulator"].location != NSNotFound) {
                // Init transport config structure
                pjsua_transport_config cfg;
                pjsua_transport_config_default(&cfg);
                cfg.port = 5060;
                
                // Add TCP transport.
                status = pjsua_transport_create(PJSIP_TRANSPORT_TCP, &cfg, &tid);
                if (status != PJ_SUCCESS)
                    error_exit("Error creating transport", status);
            }
            else {
                // Init transport config structure
                pjsua_transport_config cfg;
                pjsua_transport_config_default(&cfg);
                cfg.port = 5061;
                //        cfg.tls_setting.verify_client = PJ_FALSE;
                //        cfg.tls_setting.verify_server = PJ_FALSE;
                //        cfg.tls_setting.method = PJSIP_TLSV1_METHOD;
                
                // Add TLS transport.
                status = pjsua_transport_create(PJSIP_TRANSPORT_TLS, &cfg, &tid);
                if (status != PJ_SUCCESS)
                    error_exit("Error creating transport", status);

            }
            
        }
        

        
        
    } @catch(NSException *theException) {
        
        NSLog(@"%@",theException.reason);
    
    } @finally {

        // Initialization is done, now start pjsua
        status = pjsua_start();
        if (status != PJ_SUCCESS) error_exit("Error starting pjsua", status);

    }
    
    
    // Register the account on local sip server
    {
        pjsua_acc_config cfg;

        pjsua_acc_config_default(&cfg);

        char sipId[MAX_SIP_ID_LENGTH];
        sprintf(sipId, "sip:%s@%s", sipUser, sipDomain);
        cfg.id = pj_str(sipId);
        
        if(withReg) {
            char regUri[MAX_SIP_REG_URI_LENGTH];
            NSString *transport = transportIdx > 0 ? (transportIdx ==2 ? @";transport=tls": @";transport=tcp") : @"";
            sprintf(regUri, "sip:%s%s", sipDomain,[transport UTF8String]);
            cfg.reg_uri = pj_str(regUri);
        }
        
        cfg.cred_count = 1;
        cfg.cred_info[0].realm = pj_str("asterisk");
        cfg.cred_info[0].scheme = pj_str("digest");
        cfg.cred_info[0].username = pj_str(sipUser);
        cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
        cfg.cred_info[0].data = pj_str("8269643");
        
        
        status = pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);

//        status = pjsua_acc_add_local(tid,PJ_TRUE,&acc_id);
        
        if (status != PJ_SUCCESS) error_exit("Error adding account", status);
//        pjsua_acc_set_default(acc_id);
//        pjsua_acc_info accInfo;
//        status = pjsua_acc_get_info(tid,&accInfo);
//        if (status != PJ_SUCCESS) error_exit("Error getting account", status);
        
    }
    pjsip_use_compact_form = PJ_TRUE;

    
    return 0;
}

/* Callback called by the library upon receiving incoming call */
static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id,
                             pjsip_rx_data *rdata)
{
    pjsua_call_info ci;
    
    PJ_UNUSED_ARG(acc_id);
    PJ_UNUSED_ARG(rdata);
    
    pjsua_call_get_info(call_id, &ci);
    
    PJ_LOG(3,(THIS_FILE, "Incoming call from %.*s!!",
              (int)ci.remote_info.slen,
              ci.remote_info.ptr));
    
    /* Automatically answer incoming calls with 200/OK */
    pjsua_call_answer(call_id, 200, NULL, NULL);
}

/* Callback called by the library when call's state has changed */
static void on_call_state(pjsua_call_id call_id, pjsip_event *e)
{
    pjsua_call_info ci;
    
    PJ_UNUSED_ARG(e);
    
    pjsua_call_get_info(call_id, &ci);
    PJ_LOG(3,(THIS_FILE, "Call %d state=%.*s", call_id,
              (int)ci.state_text.slen,
              ci.state_text.ptr));
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CALL_STATE_CHANGED" object:nil userInfo:@{@"state" : @((int)ci.state)}];
}

/* Callback called by the library when call's media state has changed */
static void on_call_media_state(pjsua_call_id call_id)
{
    pjsua_call_info ci;
    
    pjsua_call_get_info(call_id, &ci);
    
    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
        // When media is active, connect call to sound device.
        pjsua_conf_connect(ci.conf_slot, 0);
        pjsua_conf_connect(0, ci.conf_slot);
    }
}

static void on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info *info)
{
    if ( info->renew != PJ_FALSE) {
        
        pjsua_state state = pjsua_get_state();
        if(state == PJSUA_STATE_CLOSING || state == PJSUA_STATE_NULL) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{

            NSString* status =  (info->cbparam->status == PJ_SUCCESS && (info->cbparam->code >= 200 && info->cbparam->code<300)) ? @"SUCCESS" : @"FAIL";
            NSLog(@"%d", info->cbparam->status );
            
            NSLog(@"CHINA: REGISTRATION STATE CHANGED - %@",status);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"REGISTRATION_COMPLETE"
                                                                object:nil
                                                              userInfo:@{@"status" : (status?:@"")}];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LOGS_NEW_STRING"
                                                                object:nil
                                                              userInfo:@{@"log" : [@"CHINA: REGISTRATION STATE CHANGED: " stringByAppendingString:(status?:@"")]}];
        });
        
    }

}
static void on_reg_started(pjsua_acc_id acc_id, pj_bool_t renew)
{
    if(renew != PJ_FALSE) {
        pjsua_state state = pjsua_get_state();
        if(state == PJSUA_STATE_CLOSING || state == PJSUA_STATE_NULL) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{

            NSLog(@"CHINA: REGISTRATION STARTED");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LOGS_NEW_STRING" object:nil userInfo:@{@"log" : @"CHINA: REGISTRATION STARTED"}];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"REGISTRATION_STARTED" object:nil];
        });
    }
}

static void logs_cb(int level, const char *data, int len)
{
    NSString* newLog =  [[NSString alloc]  initWithCString:data encoding:NSUTF8StringEncoding];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LOGS_NEW_STRING" object:nil userInfo:@{@"log" : newLog}];
}


/* Display error and exit application */
static void error_exit(const char *title, pj_status_t status)
{
    pjsua_perror(THIS_FILE, title, status);
    pjsua_destroy();
//    exit(1);
}

void setMicEnabled(bool isEnable)
{
    if(!canStart()) {
        pjsua_conf_adjust_rx_level(0, isEnable*2);
    }
    
}

void makeCall(char* destUri)
{
    if(canStart())
        return;
    pj_status_t status;
    pj_str_t uri = pj_str(destUri);
    PJ_LOG(3,(THIS_FILE, "%s",
              uri));
//    pjsip_use_compact_form();
    status = pjsua_call_make_call(acc_id, &uri, 0, NULL, NULL, NULL);
    if (status != PJ_SUCCESS)
        error_exit("Error making call", status);
}

BOOL canStart()
{
    pjsua_state state = pjsua_get_state();
    if(state == PJSUA_STATE_NULL) {
        return YES;
    }
    return NO;
}
void endCall()
{
    @try {
        pjsua_call_hangup_all();
    } @catch(NSException *theException) {
        destroyPjsip();
    } @finally {
        
    }
}

void destroyPjsip()
{
    pjsua_destroy();
}

