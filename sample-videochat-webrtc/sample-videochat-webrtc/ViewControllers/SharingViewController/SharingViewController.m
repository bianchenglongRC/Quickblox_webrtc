//
//  SharingViewController.m
//  sample-videochat-webrtc
//
//  Created by Andrey Ivanov on 27/10/15.
//  Copyright © 2015 QuickBlox Team. All rights reserved.
//

#import "SharingViewController.h"
#import "QBRTCScreenCapture.h"
#import "SharingCell.h"
#import <GPUImage/GPUImageFramework.h>
#import <tuputechSDK/TPTechSDK.h>
#import "StickerCollectionViewCell.h"
#import <AssetsLibrary/ALAssetsLibrary.h>

#define OCRetainCount(obj) \
do { if (obj) \
printf("===============retain count = %ld================\n", CFGetRetainCount((__bridge CFTypeRef)(obj))); \
} \
while (0);



@interface SharingViewController () <UICollectionViewDelegateFlowLayout,TPRenderingDelegate>

@property (nonatomic, strong) NSArray *images;

@property (nonatomic, weak) QBRTCVideoCapture *capture;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) QBRTCScreenCapture *screenCapture;
@property (nonatomic, copy) NSIndexPath *indexPath;
@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageView *filterView;

@property (nonatomic, copy) NSArray<id<TPStickerInfo>> *stickers;
@property (nonatomic, strong) GPUImageFilterGroup *beautifyFilter;
@property (nonatomic, strong) GPUImageFilter<TPReceiveFaceKeyPointProtocol, TPStickerMgrProtocol> *stickerFilter;
@property (nonatomic, strong) GPUImageFilter<TPReceiveFaceKeyPointProtocol, TPSetRenderEventDelegateProtocol> *landmarkFilter;


@end

static NSString * const reuseIdentifier = @"SharingCell";

@implementation SharingViewController{
    //    TUPULandmark *_tupu;
    id<TPLandmarkServiceInterface> _landmarkService;
    id<TPRenderServiceInterface> _renderService;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self checkTupuService];
    
    self.collectionView.pagingEnabled = YES;
    self.collectionView.hidden = YES;
    self.images = @[@"pres_img_1", @"pres_img_2", @"pres_img_3"];
    self.view.backgroundColor = [UIColor blackColor];
    
    self.enabled = self.session.localMediaStream.videoTrack.isEnabled;
    self.capture = self.session.localMediaStream.videoTrack.videoCapture;
    [self checkTupuService];

    self.screenCapture = [[QBRTCScreenCapture alloc] initWithView:self.view];
    //Switch to sharing
    self.session.localMediaStream.videoTrack.videoCapture = self.screenCapture;
    self.collectionView.contentInset =  UIEdgeInsetsMake(0, 0, 0, 0);
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
    self.filterView = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    self.filterView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    self.filterView.clipsToBounds = YES;
    [self.filterView.layer setMasksToBounds:YES];
    self.filterView.center = self.view.center;
    
    [self.view addSubview:self.filterView];
    
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



- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!self.enabled) {
        self.session.localMediaStream.videoTrack.enabled = YES;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if ([self isMovingFromParentViewController]) {
        
        if (!self.enabled) {
            self.session.localMediaStream.videoTrack.enabled = NO;
        }
        
        self.session.localMediaStream.videoTrack.videoCapture = self.capture;
    }
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    return self.images.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    SharingCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier
                                                                  forIndexPath:indexPath];
    cell.imageName = self.images[indexPath.row];
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {

    return self.collectionView.bounds.size;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    self.indexPath =  [self.collectionView.indexPathsForVisibleItems firstObject];
    [self.collectionView.collectionViewLayout invalidateLayout];
//    self.collectionView.alpha = 0;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
//    self.collectionView.alpha = 1;
    
    [self.collectionView scrollToItemAtIndexPath:self.indexPath
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:NO];
    self.indexPath = nil;
}
    

@end
