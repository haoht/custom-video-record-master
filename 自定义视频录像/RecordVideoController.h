//
//  ShootVideoViewController.h
//  VideoRecord
//
//  Created by guimingsu on 15/5/4.
//  Copyright (c) 2015年 guimingsu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "PBJVideoPlayerController.h"
#import "MZTimerLabel.h"
#import "LeafButton.h"
#import "AudioTool.h"
#import "StatusBarTool.h"
#import "UIButton+Utils.h"
#import "UIView+Utils.h"
#import "UIViewExt.h"
#import "UIAlertView+Utils.h"
#import "SVProgressHUD.h"

@class RecordVideoController;
@protocol RecordVideoControllerDelegate <NSObject>

// 获取录制的视频文件的路径
- (void)recordVideoController:(RecordVideoController *)picker didFinishPickingVideoURL:(NSURL *)videoUrl;

@end

@interface RecordVideoController : UIViewController <PBJVideoPlayerControllerDelegate, AVCaptureFileOutputRecordingDelegate, UIAlertViewDelegate>

// 左边按钮
@property (strong, nonatomic) UIButton *leftBtn;
// 录制按钮
@property (strong, nonatomic) LeafButton *recordBtn;
// 播放按钮
@property (strong, nonatomic) UIButton *playBtn;
// 完成按钮
@property (strong, nonatomic) UIButton *doneBtn;


@property (weak, nonatomic) id <RecordVideoControllerDelegate> delegate;
@end
