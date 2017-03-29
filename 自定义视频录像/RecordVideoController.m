//
//  ShootVideoViewController.m
//  VideoRecord
//
//  Created by guimingsu on 15/5/4.
//  Copyright (c) 2015年 guimingsu. All rights reserved.
//

#define SVProgressHUD_DISMISS           [SVProgressHUD dismiss];
#define SVProgressHUD_SHOW_(str)        [SVProgressHUD showWithStatus:str maskType:SVProgressHUDMaskTypeClear];

#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)

#define SANDBOX_DOCUMENT_PATH       [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]

#define FILE_MANAGER [NSFileManager defaultManager]

#import "RecordVideoController.h"

#define TIMER_INTERVAL 0.05
#define VIDEO_FOLDER @"videoFolder"
#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface RecordVideoController ()

@property float totalTime; //视频总长度 默认30秒

@property (strong,nonatomic) AVCaptureSession *captureSession;//负责输入和输出设置之间的数据传递
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;//视频输出流
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层

@property (strong,nonatomic)  UIView *viewContainer;//视频容器
@property (strong,nonatomic)  UIImageView *focusCursor; //聚焦光标

@end

@implementation RecordVideoController
{
    NSMutableArray* urlArray;//保存视频片段的数组
    
    float currentTime; //当前视频长度
    
    NSTimer *countTimer; //计时器
    UIView *progressPreView; //进度条
    float progressStep; //进度条每次变长的最小单位
    
    float preLayerWidth;//镜头宽
    float preLayerHeight;//镜头高
    float preLayerHWRate; //高，宽比
    
    UIButton *flashBtn;//闪光灯
    UIButton *cameraBtn;//切换摄像头
    
    MZTimerLabel *timerLabel;//顶部时间label
    
    BOOL didStartedRecord;//是否开始了录制
    
    BOOL didPausedRecord;//是否暂停了录制
    
    NSURL *_videoUrl;// 视频路径
    
    UIAlertView *cancelVideoRecordAlert;// 取消视频录制alert
    
    NSURL *_mergeFileURL;// 拼接视频最终完整路径
}

#pragma mark - init
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColorFromRGB(0x1d1e20);
    
    // app进入后台通知
    [NOTIFICATION_CENTER addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [NOTIFICATION_CENTER addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    
    
    //视频最大时长 默认30秒
    if (_totalTime==0) {
        _totalTime =30;
    }

    urlArray = [[NSMutableArray alloc]init];
    
    preLayerWidth = SCREEN_WIDTH;
    preLayerHeight = SCREEN_HEIGHT;
    preLayerHWRate =SCREEN_HEIGHT/SCREEN_WIDTH;
    
    progressStep = SCREEN_WIDTH*TIMER_INTERVAL/_totalTime;
    
    [self createVideoFolderIfNotExist];
    
    // 初始化整个屏幕UI
    [self initCaptureUI];
    
    // 播放按钮
    [self initPlayBtn];
    
    // 初始化视频配置
    [self setupConfiguration];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // 隐藏状态栏
    [[StatusBarTool sharedInstance] hideStatusBar];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!_captureSession.running)
    {
        [_captureSession startRunning];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // 显示状态栏
    [[StatusBarTool sharedInstance] showStatusBar];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //还原数据--------------------------------------------------
    [self deleteAllVideos];
    currentTime = 0;
    progressPreView.frame = CGRectMake(0, 0, 0, 4);
    _doneBtn.hidden = YES;
}

- (void)dealloc
{
    // 移除通知
    [NOTIFICATION_CENTER removeObserver:self];
}

#pragma mark - private
// 初始化整个屏幕UI
-(void)initCaptureUI
{
    //视频容器
    _viewContainer = [[UIView alloc]initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    [self.view addSubview:_viewContainer];
    
    //聚焦光标
//    _focusCursor = [[UIImageView alloc]initWithFrame:CGRectMake(100, 100, 50, 50)];
//    [_focusCursor setImage:[UIImage imageNamed:@"focusImg"]];
//    _focusCursor.alpha = 0;
//    [_viewContainer addSubview:_focusCursor];
    
    // 顶部透明视图
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 44)];
    topView.backgroundColor = UIColorFromRGB(0x1d1e20);
    topView.alpha = 0.5;
    [self.view addSubview:topView];
    
    // 底部透明视图
    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT-80, SCREEN_WIDTH, 80)];
    bottomView.backgroundColor = UIColorFromRGB(0x1d1e20);
    bottomView.alpha = 0.5;
    [self.view addSubview:bottomView];

    // 录制按钮
    _recordBtn = [[LeafButton alloc]initWithFrame:CGRectMake(0, 0, 132/2, 132/2)];
    _recordBtn.center = CGPointMake(SCREEN_WIDTH/2, preLayerHeight-39);
    _recordBtn.type = LeafButtonTypeVideo;
    [self.view addSubview:_recordBtn];
    
    __weak RecordVideoController *weakSelf = self;
    [_recordBtn setClickedBlock:^(LeafButton *button) {
        // 录制按钮 点击
        [weakSelf recordBtnClick];
    }];
    
    
    // 左边按钮
    _leftBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 60, 60)];
    _leftBtn.center = CGPointMake(35, SCREEN_HEIGHT - 36);
    [_leftBtn setTitle:@"取消" forState:UIControlStateNormal];
    [_leftBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_leftBtn addTarget:self action:@selector(leftBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_leftBtn];
    // 扩大点击区域
    [_leftBtn setEnlargeEdge:20];
    
    
    // 完成按钮
    _doneBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 60, 60)];
    _doneBtn.center = CGPointMake(SCREEN_WIDTH-35, SCREEN_HEIGHT - 36);
    [_doneBtn setTitle:@"完成" forState:UIControlStateNormal];
    [_doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_doneBtn addTarget:self action:@selector(doneBtnClick) forControlEvents:UIControlEventTouchUpInside];
    _doneBtn.hidden = YES;
    [self.view addSubview:_doneBtn];
    // 扩大点击区域
    [_doneBtn setEnlargeEdge:20];
    
    
    //进度条
    progressPreView = [UIView new];
    progressPreView.frame = CGRectMake(0, 0, 0, 4);
    progressPreView.backgroundColor = [UIColor whiteColor];
    [progressPreView makeCornerRadius:4/2 borderColor:nil borderWidth:0];
    [bottomView addSubview:progressPreView];
    
    //闪光灯
    flashBtn = [[UIButton alloc]initWithFrame:CGRectMake(6, 4, 34, 34)];
    [flashBtn setBackgroundImage:[UIImage imageNamed:@"flashOn"] forState:UIControlStateNormal];
    [flashBtn makeCornerRadius:34/2 borderColor:nil borderWidth:0];
    [flashBtn addTarget:self action:@selector(flashBtTap:) forControlEvents:UIControlEventTouchUpInside];
    [topView addSubview:flashBtn];
    
    //切换摄像头
    cameraBtn = [[UIButton alloc]initWithFrame:CGRectMake(SCREEN_WIDTH-40, 4, 34, 34)];
    [cameraBtn setBackgroundImage:[UIImage imageNamed:@"changeCamer"] forState:UIControlStateNormal];
    [cameraBtn makeCornerRadius:34/2 borderColor:nil borderWidth:0];
    [cameraBtn addTarget:self action:@selector(changeCamera:) forControlEvents:UIControlEventTouchUpInside];
    [topView addSubview:cameraBtn];
    
    //顶部时间label
    timerLabel = [[MZTimerLabel alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
    timerLabel.center = CGPointMake(SCREEN_WIDTH/2, 22);
    timerLabel.textAlignment = NSTextAlignmentCenter;
    timerLabel.textColor = [UIColor whiteColor];
    timerLabel.font = [UIFont systemFontOfSize:20];
    [self.view addSubview:timerLabel];
    
    // 重置计时
    [timerLabel reset];
    [timerLabel pause];
}

// 播放按钮
- (void)initPlayBtn
{
    _playBtn = [UIButton buttonWithType:0];
    [_playBtn setBackgroundImage:[UIImage imageNamed:@"btn_preview_play"] forState:UIControlStateNormal];
    [_playBtn setBackgroundImage:[UIImage imageNamed:@"btn_preview_play"] forState:UIControlStateHighlighted];
    [_playBtn addTarget:self action:@selector(playBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playBtn];
    
    _playBtn.frame = CGRectMake((SCREEN_WIDTH - 132/2)/2, SCREEN_HEIGHT - 132/2 - 6, 132/2, 132/2);
    _playBtn.hidden = YES;
}

// 初始化视频配置
- (void)setupConfiguration
{
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];
    
    //设置分辨率
//    self.captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    
    
    //获得输入设备
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
    //添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:nil];
    
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:nil];
    
    //初始化设备输出对象，用于获得输出数据
    _captureMovieFileOutput=[[AVCaptureMovieFileOutput alloc]init];
    
    // 必须写, 否则偶尔会崩!!!
    [_captureSession beginConfiguration];
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput] && [_captureSession canAddInput:audioCaptureDeviceInput])
    {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        
        if ([captureConnection isVideoStabilizationSupported ])
        {
            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput])
    {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    // 必须写, 否则偶尔会崩!!!
    [_captureSession commitConfiguration];
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:_captureSession];
    _captureVideoPreviewLayer.frame=  _viewContainer.bounds;
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    _captureVideoPreviewLayer.contentsGravity = kCAGravityResizeAspectFill;
    [_viewContainer.layer insertSublayer:_captureVideoPreviewLayer atIndex:0];
    
//    [self addGenstureRecognizer];
}

#pragma mark - timer
// 开启定时器
-(void)startTimer
{
    countTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
    [countTimer fire];
}

// 停止定时器 (永久停止)
- (void)stopTimer
{
    [countTimer invalidate]; //这个是唯一一个可以将计时器从runloop中移出的方法
    countTimer = nil;
}

// 暂停定时器 (关闭)
- (void)pauseTimer
{
    [countTimer setFireDate:[NSDate distantFuture]];
}

// 恢复定时器 (开启)
- (void)recoverTimer
{
    [countTimer setFireDate:[NSDate distantPast]];
}

#pragma mark - tool
// 拼接视频最终完整路径
- (void)mergeAndExportVideosAtFileURLs:(NSMutableArray *)fileURLArray success:(void (^)(NSURL *mergeFileURL))successBlock
{
    CGSize renderSize = CGSizeMake(0, 0);
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    CMTime totalDuration = kCMTimeZero;
    
    NSMutableArray *assetTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];
    for (NSURL *fileURL in fileURLArray) {
        
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        [assetArray addObject:asset];
        
        NSArray* tmpAry =[asset tracksWithMediaType:AVMediaTypeVideo];
        if (tmpAry.count>0) {
            AVAssetTrack *assetTrack = [tmpAry objectAtIndex:0];
            [assetTrackArray addObject:assetTrack];
            renderSize.width = MAX(renderSize.width, assetTrack.naturalSize.height);
            renderSize.height = MAX(renderSize.height, assetTrack.naturalSize.width);
        }
    }
    
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    
    for (int i = 0; i < [assetArray count] && i < [assetTrackArray count]; i++) {
        
        AVAsset *asset = [assetArray objectAtIndex:i];
        AVAssetTrack *assetTrack = [assetTrackArray objectAtIndex:i];
        
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        NSArray*dataSourceArray= [asset tracksWithMediaType:AVMediaTypeAudio];
        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:([dataSourceArray count]>0)?[dataSourceArray objectAtIndex:0]:nil
                             atTime:totalDuration
                              error:nil];
        
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:assetTrack
                             atTime:totalDuration
                              error:nil];
        
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        
        CGFloat rate;
        rate = renderW / MIN(assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        
        CGAffineTransform layerTransform = CGAffineTransformMake(assetTrack.preferredTransform.a, assetTrack.preferredTransform.b, assetTrack.preferredTransform.c, assetTrack.preferredTransform.d, assetTrack.preferredTransform.tx * rate, assetTrack.preferredTransform.ty * rate);
        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, 0));
        layerTransform = CGAffineTransformScale(layerTransform, rate, rate);
        
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        [layerInstruciton setOpacity:0.0 atTime:totalDuration];

        [layerInstructionArray addObject:layerInstruciton];
    }
    
    NSString *path = [self getVideoMergeFilePathString];
    NSURL *mergeFileURL = [NSURL fileURLWithPath:path];
    
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 100);
    mainCompositionInst.renderSize = CGSizeMake(renderW, renderW * preLayerHWRate);
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //是否暂停了录制
            if (!didPausedRecord)
            {
                // 保存视频到系统相册
//                [self saveToAlbum:mergeFileURL];
                
                // 拼接视频最终完整路径
                _mergeFileURL = mergeFileURL;
                
                SVProgressHUD_DISMISS;
                successBlock(mergeFileURL);
            }
        });
    }];
    
    
    
    //是否暂停了录制
    if (!didPausedRecord)
    {
        SVProgressHUD_SHOW_(@"正在保存视频...");
    }
}

//最后合成为 mp4
- (NSString *)getVideoMergeFilePathString
{
    NSString *path = [SANDBOX_DOCUMENT_PATH stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@"merge.mp4"];
    
    return fileName;
}

//录制保存的时候要保存为 mov
- (NSString *)getVideoSaveFilePathString
{
    NSString *path = [SANDBOX_DOCUMENT_PATH stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mov"];
    
    return fileName;
}

- (void)createVideoFolderIfNotExist
{
    NSString *folderPath = [SANDBOX_DOCUMENT_PATH stringByAppendingPathComponent:VIDEO_FOLDER];
    
    BOOL isDir = NO;
    BOOL isDirExist = [FILE_MANAGER fileExistsAtPath:folderPath isDirectory:&isDir];
    
    if(!(isDirExist && isDir))
    {
        BOOL bCreateDir = [FILE_MANAGER createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"创建保存视频文件夹失败");
        }
    }
}
- (void)deleteAllVideos
{
    for (NSURL *videoFileURL in urlArray) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *filePath = [[videoFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            if ([FILE_MANAGER fileExistsAtPath:filePath]) {
                NSError *error = nil;
                [FILE_MANAGER removeItemAtPath:filePath error:&error];
                
                if (error) {
                    NSLog(@"delete All Video 删除视频文件出错:%@", error);
                }
            }
        });
    }
    [urlArray removeAllObjects];
}

// 保存视频到系统相册
- (void)saveToAlbum:(NSURL *)videoUrl
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:videoUrl completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"Save video fail");
        } else {
            NSLog(@"Save video succeed");
        }
    }];
}

// 播放开始录像声音
- (void)playSoundRecordStarted
{
    NSString *path = @"/System/Library/Audio/UISounds/begin_record.caf";
    [[AudioTool sharedInstance] playWithPath:path delegate:nil];
}

// 播放结束录像声音
- (void)playSoundRecordEnded
{
    NSString *path = @"/System/Library/Audio/UISounds/end_record.caf";
    [[AudioTool sharedInstance] playWithPath:path delegate:nil];
}


#pragma mark - 私有方法
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [_captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

-(void)setTorchMode:(AVCaptureTorchMode )torchMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isTorchModeSupported:torchMode]) {
            [captureDevice setTorchMode:torchMode];
        }
    }];
}

-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}

-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [_viewContainer addGestureRecognizer:tapGesture];
}

-(void)setFocusCursorWithPoint:(CGPoint)point{
    _focusCursor.center=point;
    _focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    _focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        _focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        _focusCursor.alpha=0;
        
    }];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate  视频文件输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    NSLog(@"开始录制...");
    
    // 开启定时器
    [self startTimer];
}

-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"暂停录制 或者 停止录制...");
    
    [urlArray addObject:outputFileURL];
    
    //时间到了
    if (currentTime>=_totalTime)
    {
        // 隐藏录制按钮
        _recordBtn.hidden = YES;
        
        // 显示播放按钮
        _playBtn.hidden = NO;
        
        // 显示完成按钮
        _doneBtn.hidden = NO;
        
        // 显示切换摄像头
        cameraBtn.hidden = NO;
        
        [_leftBtn setTitle:@"重拍" forState:UIControlStateNormal];
        
        // 暂停计时
        [timerLabel pause];
        
        // 停止定时器 (永久停止)
        [self stopTimer];
        currentTime=_totalTime+10;
        
        // 拼接视频最终完整路径
        [self mergeAndExportVideosAtFileURLs:urlArray success:^(NSURL *mergeFileURL) {
            
            _videoUrl = mergeFileURL;
        }];
    }
    else
    {
        // 拼接视频最终完整路径
        [self mergeAndExportVideosAtFileURLs:urlArray success:^(NSURL *mergeFileURL) {
            
            _videoUrl = mergeFileURL;
        }];
    }
}

#pragma mark - PBJVideoPlayerControllerDelegate
- (void)videoPlayerPlaybackStateDidChange:(PBJVideoPlayerController *)videoPlayer
{
    if (videoPlayer.playbackState == PBJVideoPlayerPlaybackStatePaused)
    {
        // 此时状态: 已暂停播放
        [videoPlayer.stopPlayBtn setBackgroundImage:[UIImage imageNamed:@"btn_preview_play"] forState:UIControlStateNormal];
        [videoPlayer.stopPlayBtn setBackgroundImage:[UIImage imageNamed:@"btn_preview_play"] forState:UIControlStateHighlighted];
    }
    
    else if (videoPlayer.playbackState == PBJVideoPlayerPlaybackStatePlaying)
    {
        // 此时状态: 正在播放
        [videoPlayer.stopPlayBtn setBackgroundImage:[UIImage imageNamed:@"btn_preview_stop"] forState:UIControlStateNormal];
        [videoPlayer.stopPlayBtn setBackgroundImage:[UIImage imageNamed:@"btn_preview_stop"] forState:UIControlStateHighlighted];
    }
}

// 点击了停止播放按钮
- (void)videoPlayerDidSelectedStopPlayBtn:(PBJVideoPlayerController *)videoPlayer
{
    // 显示完成按钮
    _doneBtn.hidden = NO;
    
    //----------------------------------------------------------------------------------------------------
    
    if (videoPlayer.playbackState == PBJVideoPlayerPlaybackStatePaused)
    {
        // 此时状态: 已暂停播放
        [videoPlayer playFromCurrentTime];
        
        [videoPlayer.stopPlayBtn setBackgroundImage:[UIImage imageNamed:@"btn_preview_stop"] forState:UIControlStateNormal];
        [videoPlayer.stopPlayBtn setBackgroundImage:[UIImage imageNamed:@"btn_preview_stop"] forState:UIControlStateHighlighted];
    }
    
    else if (videoPlayer.playbackState == PBJVideoPlayerPlaybackStatePlaying)
    {
        // 此时状态: 正在播放
        [videoPlayer playFromCurrentTime];
        
        [videoPlayer dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)videoPlayerPlaybackDidEnd:(PBJVideoPlayerController *)videoPlayer
{
    // 显示完成按钮
    _doneBtn.hidden = NO;
    
    [videoPlayer dismissViewControllerAnimated:NO completion:nil];
}

- (void)videoPlayerReady:(PBJVideoPlayerController *)videoPlayer
{
    
}
- (void)videoPlayerPlaybackWillStartFromBeginning:(PBJVideoPlayerController *)videoPlayer
{
    
}


#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == cancelVideoRecordAlert) //取消视频录制alert
    {
        if (buttonIndex == 0)
        {
            //取消录像
            [self dismissViewControllerAnimated:YES completion:nil];
            
            if (_captureSession.running)
            {
                [_captureSession stopRunning];
            }
        }
        
        if (buttonIndex == 1)
        {
            //继续录像
        }
    }
}


#pragma mark - target action
// 计时器
- (void)timerAction
{
    currentTime += TIMER_INTERVAL;
    float progressWidth = progressPreView.width + progressStep;
    progressPreView.frame = CGRectMake(0, 0, progressWidth, 4);
    
    //时间到了停止录制视频
    if (currentTime>=_totalTime)
    {
        // 停止定时器 (永久停止)
        [self stopTimer];
        // 停止录制
        [_captureMovieFileOutput stopRecording];
    }
}

// 左边按钮 点击
- (void)leftBtnClick:(UIButton *)btn
{
    if ([_leftBtn.titleLabel.text isEqualToString:@"取消"])
    {
        if ([_captureMovieFileOutput isRecording])
        {
            // 如果正在录制, 则先暂停:
            
            //是否暂停了录制
            didPausedRecord = YES;
            
            // 暂停定时器 (关闭)
            [self pauseTimer];
            // 停止录制
            [_captureMovieFileOutput stopRecording];
            
            // 暂停计时
            [timerLabel pause];
            
            _recordBtn.state = LeafButtonStateNormal;
        }
        
        //-------------------------------------------------------------------------------------------------------------
        if (didStartedRecord)//是否开始了录制
        {
            if (btn) {
                cancelVideoRecordAlert = [[UIAlertView alloc] initWithTitle:@"" message:@"确定取消录像吗? 已录下的视频将不会被保存" delegate:self cancelButtonTitle:@"取消录像" otherButtonTitles:@"继续录像", nil];
                [cancelVideoRecordAlert show];
            }
        }
        else
        {
            [self dismissViewControllerAnimated:YES completion:nil];
            
            if (_captureSession.running)
            {
                [_captureSession stopRunning];
            }
        }
    }
    
    else if ([_leftBtn.titleLabel.text isEqualToString:@"重拍"])
    {
        [_leftBtn setTitle:@"取消" forState:UIControlStateNormal];
        
        // 重置计时
        [timerLabel reset];
        
        // 重置进度条
        currentTime = 0;
        progressPreView.width = 0;
        
        // 显示录制按钮
        _recordBtn.hidden = NO;
        // 隐藏播放按钮
        _playBtn.hidden = YES;
        
        // 隐藏完成按钮
        _doneBtn.hidden = YES;

        // 保存视频到系统相册
        [self saveToAlbum:_mergeFileURL];
        
        // 清除之前录制的视频片段
        [self deleteAllVideos];
    }
}

// 录制按钮 点击
- (void)recordBtnClick
{
    // 隐藏切换摄像头
    cameraBtn.hidden = YES;
    
    //是否暂停了录制
    didPausedRecord = NO;
    
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //根据连接取得设备输出的数据
    if (![_captureMovieFileOutput isRecording])
    {
        //--------------------------- 开始录制 ------------------------
        [self playSoundRecordStarted];
        
        if (captureConnection.active)
        {
            GCD_DELAY_AFTER(0.5, ^{//避免把系统提示音也录进去
                
                //预览图层和视频方向保持一致
                captureConnection.videoOrientation=[_captureVideoPreviewLayer connection].videoOrientation;
                [_captureMovieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[self getVideoSaveFilePathString]] recordingDelegate:self];
                
                //开始计时
                [timerLabel start];
                
                //是否开始了录制
                didStartedRecord = YES;
            });
        }
        else
        {
            // 还原
            cameraBtn.hidden = NO;
            didPausedRecord = YES;
            _recordBtn.state = LeafButtonStateNormal;
            
            [UIAlertView showWithMessage:@"初始化相机失败, 请重试"];
        }
    }
    else
    {
        //--------------------------- 停止录制 ------------------------
        [self playSoundRecordEnded];
        
        GCD_DELAY_AFTER(0.5, ^{
            // 隐藏录制按钮
            _recordBtn.hidden = YES;
            // 显示播放按钮
            _playBtn.hidden = NO;
        });
        
        // 暂停计时
        [timerLabel pause];
        
        // 重置进度条
        currentTime = 0;
        progressPreView.width = 0;
        
        // 显示摄像头切换
        cameraBtn.hidden = NO;
        
        // 显示完成按钮
        _doneBtn.hidden = NO;
        
        //是否开始了录制
        didStartedRecord = NO;
        
        [_leftBtn setTitle:@"重拍" forState:UIControlStateNormal];
        
        
        // 停止定时器 (永久停止)
        [self stopTimer];
        
        currentTime=_totalTime+10;
        
        // 停止录制
        [_captureMovieFileOutput stopRecording];
    }
}

// 完成按钮 点击
-(void)doneBtnClick
{
    if (_videoUrl)
    {
        // 1.停止定时器 (永久停止)
        [self stopTimer];
        currentTime=_totalTime+10;
        
        // 2.获取录制的视频文件的路径
        if ([_delegate respondsToSelector:@selector(recordVideoController:didFinishPickingVideoURL:)])
        {
            [_delegate recordVideoController:self didFinishPickingVideoURL:_videoUrl];
        }
        
        [self dismissViewControllerAnimated:YES completion:nil];
        
        // 3.
        if (_captureSession.running)
        {
            [_captureSession stopRunning];
        }
    }
    else
    {
        [UIAlertView showWithMessage:@"视频录制失败"];
    }
}

// 播放按钮
- (void)playBtnClick
{
    if (_videoUrl)
    {
        // 播放视频
        PBJVideoPlayerController *videoPlayer = [[PBJVideoPlayerController alloc] init];
        videoPlayer.delegate = self;
        videoPlayer.view.frame = self.view.bounds;
        videoPlayer.videoURL = _videoUrl;
        
        // 必须延迟0.3秒, 否则会一闪, 影响用户体验
        GCD_DELAY_AFTER(0.3, ^{
            [self presentViewController:videoPlayer animated:NO completion:nil];
            [videoPlayer playFromBeginning];
        });
    }
    else
    {
        [UIAlertView showWithMessage:@"视频录制失败"];
    }
}

// 闪光灯按钮 点击
-(void)flashBtTap:(UIButton *)btn
{
    if (btn.selected == YES) {
        btn.selected = NO;
        //关闭闪光灯
        [flashBtn setBackgroundImage:[UIImage imageNamed:@"flashOn"] forState:UIControlStateNormal];
        [self setTorchMode:AVCaptureTorchModeOff];
    }
    else
    {
        btn.selected = YES;
        //开启闪光灯
        [flashBtn setBackgroundImage:[UIImage imageNamed:@"flashOff"] forState:UIControlStateNormal];
        [self setTorchMode:AVCaptureTorchModeOn];
    }
}

// 切换前后摄像头
- (void)changeCamera:(UIButton *)btn
{
    AVCaptureDevice *currentDevice=[_captureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified||currentPosition==AVCaptureDevicePositionFront)
    {
        toChangePosition=AVCaptureDevicePositionBack;
        flashBtn.hidden = NO;
    }
    else
    {
        flashBtn.hidden = YES;
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [_captureSession beginConfiguration];
    //移除原有输入对象
    [_captureSession removeInput:_captureDeviceInput];
    //添加新的输入对象
    if ([_captureSession canAddInput:toChangeDeviceInput])
    {
        [_captureSession addInput:toChangeDeviceInput];
        _captureDeviceInput=toChangeDeviceInput;
    }
    //提交会话配置
    [_captureSession commitConfiguration];
    
    //关闭闪光灯
    flashBtn.selected = NO;
    [flashBtn setBackgroundImage:[UIImage imageNamed:@"flashOn"] forState:UIControlStateNormal];
    [self setTorchMode:AVCaptureTorchModeOff];
}

// 点击了屏幕
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture
{
    CGPoint point= [tapGesture locationInView:_viewContainer];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [_captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

#pragma mark - notification
// app进入后台通知
- (void)applicationWillResignActive
{
    if (didStartedRecord)//是否开始了录制
    {
        if (!didPausedRecord)//是否暂停了录制
        {
            // 此时正在录像, 则先暂停
            [self leftBtnClick:nil];
        }
    }
}
- (void)applicationDidEnterBackground
{
    [self applicationWillResignActive];
}

@end
