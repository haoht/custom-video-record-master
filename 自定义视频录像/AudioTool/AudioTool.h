//
//  AudioRecordTool.h
//  1111111111
//
//  Created by liman on 8/4/15.
//  Copyright (c) 2015年 liman. All rights reserved.
//

#define GCD_DELAY_AFTER(time, block) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC), dispatch_get_main_queue(), block)
#define NOTIFICATION_CENTER [NSNotificationCenter defaultCenter]
#define kNOTIFICATON_AUDIO_PLAY_DONE                                 @"audio_play_done_notification"
#define GCD_SYSTEM_MAIN(block) dispatch_async(dispatch_get_main_queue(),block)



#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class AudioTool;
@protocol AudioToolDelegate <NSObject>

// 录音成功
- (void)audioTool:(AudioTool *)audioTool recordSuccess:(AVAudioRecorder *)recorder;
// 录音失败
- (void)audioTool:(AudioTool *)audioTool recordFail:(AVAudioRecorder *)recorder;
// 正在录音...
- (void)audioTool:(AudioTool *)audioTool recording:(AVAudioRecorder *)recorder normalizedValue:(CGFloat)normalizedValue;

// 播放成功
- (void)audioTool:(AudioTool *)audioTool playSuccess:(AVAudioPlayer *)player;
// 播放失败
- (void)audioTool:(AudioTool *)audioTool playFail:(AVAudioPlayer *)player;
// 正在播放...
- (void)audioTool:(AudioTool *)audioTool playing:(AVAudioPlayer *)player normalizedValue:(CGFloat)normalizedValue;

@end

@interface AudioTool : NSObject <AVAudioRecorderDelegate, AVAudioPlayerDelegate>

// 单例
+ (AudioTool *)sharedInstance;

// 清除AudioTool单例 (否则出现第二次录音失败的bug)
+ (void)clearSharedInstance;

@property (strong, nonatomic) AVAudioRecorder *recorder;
@property (strong, nonatomic) AVAudioPlayer *player;

/**
 *  开始录音
 */
- (void)recordToPath:(NSString *)path delegate:(id<AudioToolDelegate>)delegate;

/**
 *  停止录音
 */
- (void)stopRecord;

/**
 *  暂停录音
 */
- (void)pauseRecord;


/**
 *  开始播放
 */
- (void)playWithPath:(NSString *)path delegate:(id<AudioToolDelegate>)delegate;

/**
 *  停止播放
 */
- (void)stopPlayWithPath:(NSString *)path;

@property (weak, nonatomic) id <AudioToolDelegate> delegate;
@end
