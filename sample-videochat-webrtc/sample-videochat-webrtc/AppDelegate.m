//
//  AppDelegate.m
//  QBRTCChatSample
//
//  Created by Andrey Ivanov on 04.12.14.
//  Copyright (c) 2014 QuickBlox Team. All rights reserved.
//

#import "AppDelegate.h"
#import "SVProgressHUD.h"
#import "QBCore.h"
#import "Settings.h"
#import <tuputechSDK/TPTechSDK.h>


#define TP_APP_KEY @"4362828a8e8d819a732a23f5c801c3a5"
#define TP_APP_SECRET @"8a44549bc215edb57b4f508c38db5ab27e6b09ce"

const CGFloat kQBRingThickness = 1.f;
const NSTimeInterval kQBAnswerTimeInterval = 60.f;
const NSTimeInterval kQBDialingTimeInterval = 5.f;

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.window.backgroundColor = [UIColor whiteColor];
    
    id<TPSDKAuthInterface> authService = [TPTechSDK createTPAuthService];
    [authService autoInstallLicenseBySDKWithAppkey:TP_APP_KEY appSecret:TP_APP_SECRET serviceIDs:@[@(TPFaceCheckService)] complete:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Install tuputech liscense success!");
        } else {
            NSLog(@"Install tuputech liscense failed, err = [%@]", [error domain]);
        }
    }];
    
    [QBSettings setAccountKey:@"7yvNe17TnjNUqDoPwfqp"];
    [QBSettings setApplicationID:40718];
    [QBSettings setAuthKey:@"AnB-JpA6r4y6RmS"];
    [QBSettings setAuthSecret:@"3O7Sr5Pg4Qjexwn"];
    
    [QBSettings setLogLevel:QBLogLevelDebug];
    [QBSettings enableXMPPLogging];
    
    [QBRTCConfig setAnswerTimeInterval:kQBAnswerTimeInterval];
    [QBRTCConfig setDialingTimeInterval:kQBDialingTimeInterval];
    [QBRTCConfig setStatsReportTimeInterval:1.f];
    
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
    
    [QBRTCClient initializeRTC];
    
    // loading settings
    [Settings instance];
    
    return YES;
}

#pragma mark - Remote Notifictions

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    
    if (notificationSettings.types != UIUserNotificationTypeNone) {
        
        NSLog(@"Did register user notificaiton settings");
        [application registerForRemoteNotifications];
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    NSLog(@"Did register for remote notifications with device token");
    [Core registerForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    
    NSLog(@"Did receive remote notification %@", userInfo);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    
    NSLog(@"Did fail to register for remote notification with error %@", error.localizedDescription);
}

@end
