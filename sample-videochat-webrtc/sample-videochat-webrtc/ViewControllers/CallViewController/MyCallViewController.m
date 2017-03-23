//
//  MyCallViewController.m
//  sample-videochat-webrtc
//
//  Created by Blues on 17/3/23.
//  Copyright © 2017年 QuickBlox Team. All rights reserved.
//

#import "MyCallViewController.h"
#import "QMSoundManager.h"
#import "UsersDataSource.h"
#import "QBCore.h"
#import "QBRTCScreenCapture.h"
#import <GPUImage/GPUImageFramework.h>
#import <tuputechSDK/TPTechSDK.h>
#import "StickerCollectionViewCell.h"
#import <AssetsLibrary/ALAssetsLibrary.h>
#import "LocalVideoView.h"

static const NSTimeInterval kRefreshTimeInterval = 1.f;


#define OCRetainCount(obj) \
do { if (obj) \
printf("===============retain count = %ld================\n", CFGetRetainCount((__bridge CFTypeRef)(obj))); \
} \
while (0);



@interface MyCallViewController ()<QBRTCClientDelegate, QBRTCAudioSessionDelegate,TPRenderingDelegate>


@property (nonatomic, strong) QBRTCScreenCapture *screenCapture;
@property (strong, nonatomic) NSMutableDictionary *videoViews;
@property (strong, nonatomic) NSMutableArray *users;

@property (assign, nonatomic) NSTimeInterval timeDuration;
@property (strong, nonatomic) NSTimer *callTimer;
@property (assign, nonatomic) NSTimer *beepTimer;


@property (nonatomic, strong) UIView *localVideoView;
@property (nonatomic, strong) UIView *opponentVideoView;
@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageView *filterView;

@property (nonatomic, copy) NSArray<id<TPStickerInfo>> *stickers;
@property (nonatomic, strong) GPUImageFilterGroup *beautifyFilter;
@property (nonatomic, strong) GPUImageFilter<TPReceiveFaceKeyPointProtocol, TPStickerMgrProtocol> *stickerFilter;
@property (nonatomic, strong) GPUImageFilter<TPReceiveFaceKeyPointProtocol, TPSetRenderEventDelegateProtocol> *landmarkFilter;


@end

@implementation MyCallViewController{
    //    TUPULandmark *_tupu;
    id<TPLandmarkServiceInterface> _landmarkService;
    id<TPRenderServiceInterface> _renderService;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"%@ - %@",  NSStringFromSelector(_cmd), self);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[QBRTCClient instance] addDelegate:self];
    [[QBRTCAudioSession instance] addDelegate:self];

    [self initView];
    
    [self checkTupuService];

    
    self.screenCapture = [[QBRTCScreenCapture alloc] initWithView:self.localVideoView];
    self.session.localMediaStream.videoTrack.videoCapture = self.screenCapture;
    self.session.localMediaStream.audioTrack.enabled = YES;
    self.session.localMediaStream.videoTrack.enabled = YES;

    
    NSMutableArray *users = [NSMutableArray arrayWithCapacity:self.session.opponentsIDs.count + 1];
    [users insertObject:Core.currentUser atIndex:0];
    
    for (NSNumber *uID in self.session.opponentsIDs) {
        
        if (Core.currentUser.ID == uID.integerValue) {
            
            QBUUser *initiator = [self.usersDatasource userWithID:self.session.initiatorID.unsignedIntegerValue];
            
            if (!initiator) {
                
                initiator = [QBUUser user];
                initiator.ID = self.session.initiatorID.integerValue;
            }
            
            [users insertObject:initiator atIndex:0];
            
            continue;
        }
        
        QBUUser *user = [self.usersDatasource userWithID:uID.integerValue];
        if (!user) {
            user = [QBUUser user];
            user.ID = uID.integerValue;
        }
        [users insertObject:user atIndex:0];
    }
    
    self.users = users;
    
    [[QBRTCAudioSession instance] initializeWithConfigurationBlock:^(QBRTCAudioSessionConfiguration *configuration) {
        // adding blutetooth support
        configuration.categoryOptions |= AVAudioSessionCategoryOptionAllowBluetooth;
        configuration.categoryOptions |= AVAudioSessionCategoryOptionAllowBluetoothA2DP;
        
        // adding airplay support
        configuration.categoryOptions |= AVAudioSessionCategoryOptionAllowAirPlay;
        
        if (_session.conferenceType == QBRTCConferenceTypeVideo) {
            // setting mode to video chat to enable airplay audio and speaker only
            configuration.mode = AVAudioSessionModeVideoChat;
        }
    }];
    
    BOOL isInitiator = (Core.currentUser.ID == self.session.initiatorID.unsignedIntegerValue);
    isInitiator ? [self startCall] : [self acceptCall];
    
    self.title = @"Connecting...";
//
    // Do any additional setup after loading the view.
}

- (void)initView {
    
    self.opponentVideoView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height/2, self.view.frame.size.width, self.view.frame.size.height/2)];
    self.opponentVideoView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:self.opponentVideoView];
    
    self.localVideoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height/2)];
    [self.view addSubview:self.localVideoView];
    
    
}

- (void)startCall {
    //Begin play calling sound
    self.beepTimer = [NSTimer scheduledTimerWithTimeInterval:[QBRTCConfig dialingTimeInterval]
                                                      target:self
                                                    selector:@selector(playCallingSound:)
                                                    userInfo:nil
                                                     repeats:YES];
    [self playCallingSound:nil];
    //Start call
    NSDictionary *userInfo = @{@"name" : @"Test",
                               @"url" : @"http.quickblox.com",
                               @"param" : @"\"1,2,3,4\""};
    
    [self.session startCall:userInfo];
}

- (void)acceptCall {
    
    [[QMSoundManager instance] stopAllSounds];
    //Accept call
    NSDictionary *userInfo = @{@"acceptCall" : @"userInfo"};
    [self.session acceptCall:userInfo];
}

- (void)checkTupuService
{
    [TPTechSDK createService:TPFaceCheckService complete:^(id service, NSError *error) {
        if (!error) {
            _landmarkService = (id<TPLandmarkServiceInterface>)service;
            OCRetainCount(_landmarkService)
            [_landmarkService setFaceRectDebugScale:0.32f];
            [_landmarkService enableDebugMode:YES];
            [self tryStartupVideoCamera];
        }
        else {
            id<TPSDKAuthInterface> authService = [TPTechSDK createTPAuthService];
            [authService autoInstallLicenseBySDKWithAppkey:@"f54b76527835ba62337c9e535d01590d" appSecret:@"8ed03bf9f6687ae7344923898794277f25248d3c" serviceIDs:@[@(TPFaceCheckService)] complete:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    [TPTechSDK createService:TPFaceCheckService complete:^(id service, NSError *error) {
                        if (!error) {
                            _landmarkService = (id<TPLandmarkServiceInterface>)service;
                            OCRetainCount(_landmarkService)
                            [_landmarkService setFaceRectDebugScale:0.32f];
                            [_landmarkService enableDebugMode:YES];
                            [self tryStartupVideoCamera];
                        }
                    }];
                }
            }];
        }
    }];
    
    [TPTechSDK createService:TPRenderingService complete:^(id service, NSError *error) {
        if (!error) {
            OCRetainCount(self.beautifyFilter)
            _renderService = (id<TPRenderServiceInterface>)service;
            GPUImageFilterGroup *beautifyFilter = [_renderService createTPBeautifyFilter];
            OCRetainCount(beautifyFilter)
            self.beautifyFilter = beautifyFilter;
            OCRetainCount(beautifyFilter)
            OCRetainCount(self.beautifyFilter)
            self.stickerFilter = [_renderService createStickerFilter];
            self.landmarkFilter = [_renderService createTPLandmarkFilter];
            [self tryStartupVideoCamera];
        }
    }];
}

- (void)tryStartupVideoCamera {
    //    printf("retain count = %ld\n", OCRetainCount(self.beautifyFilter));
    //    OCRetainCount(self.beautifyFilter)
    if (_landmarkService && _renderService && _beautifyFilter && _stickerFilter && _landmarkFilter) {
        [self p_initGPUImageFilters];
        [self.videoCamera startCameraCapture];
    }
}

- (void)p_initGPUImageFilters {
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    self.filterView = [[GPUImageView alloc] initWithFrame:_localVideoView.frame];
    self.filterView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    self.filterView.clipsToBounds = YES;
    [self.filterView.layer setMasksToBounds:YES];
    
    [self.localVideoView addSubview:self.filterView];
    self.filterView.center = self.localVideoView.center;

    
    [_landmarkFilter setReceiveRenderEventDelegate:self];
    
    [self.videoCamera addTarget: self.beautifyFilter];
    [self.beautifyFilter addTarget:self.landmarkFilter];
    [self.landmarkFilter addTarget:self.stickerFilter];
    [self.stickerFilter addTarget:self.filterView];
    
    //    [self initMovieWriter];
    
    
    //    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    //    tapRecognizer.numberOfTapsRequired = 2;
    ////    [self.HUDView addGestureRecognizer:tapRecognizer];
    //
    ////    [self.close addTarget:self action:@selector(handleClose:) forControlEvents:UIControlEventTouchUpInside];
    //
    [_stickerFilter loadStickerWithPath:@"" complete:^(NSArray<id<TPStickerInfo>> *result, NSError *err) {
        if (!err) {
            self.stickers = [result copy];
            NSLog(@"====%ld", self.stickers.count);
            //            [_stickerGalleryView reloadData];
            
            [_stickerFilter renderStickerWithIndex:0];
            
        }
    }];
    
}

#pragma mark - TPRenderDelegate

- (void)TPRenderer:(GPUImageOutput *)renderer WillBeginRender:(GPUImageFramebuffer *)buffer {
    if (renderer == self.landmarkFilter) {
        [buffer lock];
        CVPixelBufferRef pixelBuffer = buffer.pixelBuffer;
        CFRetain(pixelBuffer);
        CMFormatDescriptionRef outputFormatDescription = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &outputFormatDescription);
        
        [_landmarkService faceCheckAndLandmark:pixelBuffer smoothEnable:YES complete:^(NSError *error, BOOL isFace, NSArray<NSValue*> *keyPoints, CGRect rect) {
            if (isFace) {
                NSLog(@"==================>isFace<================");
                [_stickerFilter updateFaceKeyPoint:@[keyPoints]];
                [_landmarkFilter updateFaceKeyPoint:keyPoints];
                [_landmarkFilter updateFaceRect:rect];
            } else {
                NSLog(@"==================>Not_Face<================");
                [_stickerFilter updateFaceKeyPoint:@[]];
                [_landmarkFilter updateFaceKeyPoint:@[]];
                [_landmarkFilter updateFaceRect:CGRectNull];
            }
        } debug:^(NSString *debugInfo, UIImage *debugImg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                //                if (debugInfo) {
                //                    self.debugInfoView.text = debugInfo;
                //                }
                //
                //                if (debugImg) {
                //                    [self.debugImageView setImage:debugImg];
                //                }
            });
            
        }];
        
        CFRelease(pixelBuffer);
        [buffer unlock];
    }
}



- (UIView *)videoViewWithOpponentID:(NSNumber *)opponentID {
    
    if (self.session.conferenceType == QBRTCConferenceTypeAudio) {
        return nil;
    }
    
    if (!self.videoViews) {
        self.videoViews = [NSMutableDictionary dictionary];
    }
    
    id result = self.videoViews[opponentID];
    
    if (Core.currentUser.ID == opponentID.integerValue) {//Local preview
        if (!result) {
//            LocalVideoView *localVideoView = [[LocalVideoView alloc] initWithPreviewlayer:self.videoCamera.previewLayer];
//            self.videoViews[opponentID] = localVideoView;
//            localVideoView.delegate = self;
//            self.localVideoView = localVideoView;
            
            UIView *localVideoView = [[UIView alloc] initWithFrame:_localVideoView.frame];
            self.localVideoView = localVideoView;
            return localVideoView;
        }
    }
    else {//Opponents
        
        QBRTCRemoteVideoView *remoteVideoView = nil;
        
        QBRTCVideoTrack *remoteVideoTraсk = [self.session remoteVideoTrackWithUserID:opponentID];
        
        if (!result && remoteVideoTraсk) {
            remoteVideoView = [[QBRTCRemoteVideoView alloc] initWithFrame:CGRectMake(2, 2, 2, 2)];
            remoteVideoView.videoGravity = AVLayerVideoGravityResizeAspectFill;
            self.videoViews[opponentID] = remoteVideoView;
            result = remoteVideoView;
        }
        [remoteVideoView setVideoTrack:remoteVideoTraсk];
        return result;
    }
    
    return result;
}

#pragma mark - QBRTCClientDelegate

- (void)session:(QBRTCSession *)session updatedStatsReport:(QBRTCStatsReport *)report forUserID:(NSNumber *)userID {
    
    NSString *result = [report statsString];
    NSLog(@"%@", result);
    
    // send stats to stats view if needed
//    if (_shouldGetStats) {
//        [_statsView setStats:result];
//        [self.view setNeedsLayout];
//    }
}

/**
 * Called in case when you are calling to user, but he hasn't answered
 */
- (void)session:(QBRTCSession *)session userDoesNotRespond:(NSNumber *)userID {
    
    if (session == self.session) {
        
       
    }
}

- (void)session:(QBRTCSession *)session acceptedByUser:(NSNumber *)userID userInfo:(NSDictionary *)userInfo {
    
    if (session == self.session) {
        
       
    }
}






/**
 * Called in case when opponent has rejected you call
 */
- (void)session:(QBRTCSession *)session rejectedByUser:(NSNumber *)userID userInfo:(NSDictionary *)userInfo {
    if (session == self.session) {

    }
}


/**
 *  Called in case when opponent hung up
 */
- (void)session:(QBRTCSession *)session hungUpByUser:(NSNumber *)userID userInfo:(NSDictionary *)userInfo {
    
    if (session == self.session) {
        
    
    }
}

/**
 *  Called in case when receive remote video track from opponent
 */

- (void)session:(QBRTCSession *)session receivedRemoteVideoTrack:(QBRTCVideoTrack *)videoTrack fromUser:(NSNumber *)userID {
    if (session == self.session) {
        QBRTCRemoteVideoView *opponentVideoView = (id)[self videoViewWithOpponentID:userID];
        NSLog(@"opponentVideoView===%@", opponentVideoView);
        UIView *videoView = [[UIView alloc] init];
//        videoView.center = self.opponentVideoView.center;
        videoView = opponentVideoView;
        videoView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height/2);
        videoView.backgroundColor = [UIColor blackColor];
        [self.opponentVideoView addSubview:videoView];
    }
}



/**
 *  Called in case when connection initiated
 */
- (void)session:(QBRTCSession *)session startedConnectionToUser:(NSNumber *)userID {
    
    if (session == self.session) {
        
//        [self performUpdateUserID:userID block:^(OpponentCollectionViewCell *cell) {
//            cell.connectionState = [self.session connectionStateForUser:userID];
//        }];
    }
}

/**
 *  Called in case when connection is established with opponent
 */
- (void)session:(QBRTCSession *)session connectedToUser:(NSNumber *)userID {
    
    NSParameterAssert(self.session == session);
    
    if (self.beepTimer) {
        
        [self.beepTimer invalidate];
        self.beepTimer = nil;
        [[QMSoundManager instance] stopAllSounds];
    }
    
    if (!self.callTimer) {
        
        self.callTimer = [NSTimer scheduledTimerWithTimeInterval:kRefreshTimeInterval
                                                          target:self
                                                        selector:@selector(refreshCallTime:)
                                                        userInfo:nil
                                                         repeats:YES];
    }
    
//    [self performUpdateUserID:userID block:^(OpponentCollectionViewCell *cell) {
//        cell.connectionState = [self.session connectionStateForUser:userID];
//    }];
}

/**
 *  Called in case when connection state changed
 */
- (void)session:(QBRTCSession *)session connectionClosedForUser:(NSNumber *)userID {
    
    if (session == self.session) {
        
//        [self performUpdateUserID:userID block:^(OpponentCollectionViewCell *cell) {
//            cell.connectionState = [self.session connectionStateForUser:userID];
//            [self.videoViews removeObjectForKey:userID];
//            [cell setVideoView:nil];
//        }];
    }
}

/**
 *  Called in case when disconnected from opponent
 */
- (void)session:(QBRTCSession *)session disconnectedFromUser:(NSNumber *)userID {
    
    if (session == self.session) {
        
//        [self performUpdateUserID:userID block:^(OpponentCollectionViewCell *cell) {
//            cell.connectionState = [self.session connectionStateForUser:userID];
//        }];
    }
}

/**
 *  Called in case when disconnected by timeout
 */
- (void)session:(QBRTCSession *)session disconnectedByTimeoutFromUser:(NSNumber *)userID {
    
    if (session == self.session) {
        
//        [self performUpdateUserID:userID block:^(OpponentCollectionViewCell *cell) {
//            cell.connectionState = [self.session connectionStateForUser:userID];
//        }];
    }
}

/**
 *  Called in case when connection failed with user
 */
- (void)session:(QBRTCSession *)session connectionFailedWithUser:(NSNumber *)userID {
    
    if (session == self.session) {
        
//        [self performUpdateUserID:userID block:^(OpponentCollectionViewCell *cell) {
//            cell.connectionState = [self.session connectionStateForUser:userID];
//        }];
    }
}


/**
 *  Called in case when session will close
 */
- (void)sessionDidClose:(QBRTCSession *)session {
    
    if (session == self.session) {
        
//        [self.cameraCapture stopSession:nil];

        [self.videoCamera stopCameraCapture];
        [[QBRTCAudioSession instance] deinitialize];
        
        if (self.beepTimer) {
            
            [self.beepTimer invalidate];
            self.beepTimer = nil;
            [[QMSoundManager instance] stopAllSounds];
        }
        
        [self.callTimer invalidate];
        self.callTimer = nil;
//        
//        self.toolbar.userInteractionEnabled = NO;
//        [UIView animateWithDuration:0.5 animations:^{
//            
//            self.toolbar.alpha = 0.4;
//        }];
        
        self.title = [NSString stringWithFormat:@"End - %@", [self stringWithTimeDuration:self.timeDuration]];
    }
}

#pragma mark - QBRTCAudioSessionDelegate

- (void)audioSession:(QBRTCAudioSession *)audioSession didChangeCurrentAudioDevice:(QBRTCAudioDevice)updatedAudioDevice {
    
    BOOL isSpeaker = updatedAudioDevice == QBRTCAudioDeviceSpeaker;
//    if (self.dynamicEnable.pressed != isSpeaker) {
//        
//        self.dynamicEnable.pressed = isSpeaker;
//    }
}

#pragma mark - Timers actions

- (void)playCallingSound:(id)sender {
    
    [QMSoundManager playCallingSound];
}

- (void)refreshCallTime:(NSTimer *)sender {
    
    self.timeDuration += kRefreshTimeInterval;
    self.title = [NSString stringWithFormat:@"Call time - %@", [self stringWithTimeDuration:self.timeDuration]];
}

- (NSString *)stringWithTimeDuration:(NSTimeInterval )timeDuration {
    
    NSInteger minutes = timeDuration / 60;
    NSInteger seconds = (NSInteger)timeDuration % 60;
    
    NSString *timeStr = [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
    
    return timeStr;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
