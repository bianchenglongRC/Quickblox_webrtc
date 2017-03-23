//
//  MyCallViewController.h
//  sample-videochat-webrtc
//
//  Created by Blues on 17/3/23.
//  Copyright © 2017年 QuickBlox Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@class QBRTCSession;
@class UsersDataSource;

@interface MyCallViewController : UIViewController

@property (strong, nonatomic) QBRTCSession *session;
@property (weak, nonatomic) UsersDataSource *usersDatasource;

@end
