//
//  AudioRecordTool.m
//  1111111111
//
//  Created by liman on 8/4/15.
//  Copyright (c) 2015年 liman. All rights reserved.
//

#import "AudioTool.h"

@interface AudioTool ()
{
    // 初始化配置 (只能执行一次, 否则不能暂停)
    BOOL _flag;
    
    // runLoop
    CADisplayLink *meterUpdateDisplayLink;
}

@end

@implementation AudioTool
static dispatch_once_t pred;
static AudioTool *shared = nil;

#pragma mark - 单例
// 创建单例
+ (AudioTool *)sharedInstance
{
    dispatch_once(&pred, ^{
        shared = [[AudioTool alloc] init];
    });
    return shared;
}

// 清除AudioTool单例 (否则出现第二次录音失败的bug)
+ (void)clearSharedInstance
{
    GCD_DELAY_AFTER(0.1, ^{
        shared = nil;
        pred = nil;
    });
}


#pragma mark - tool method
// 初始化配置 (只能执行一次, 否则不能暂停)
- (void)setupSettings:(NSString *)path
{
    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    // Define the recorder setting
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
    
    // Initiate and prepare the recorder
    _recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:path] settings:recordSetting error:nil];
    _recorder.delegate = self;
    _recorder.meteringEnabled = YES;
    [_recorder prepareToRecord];
}

// 开始runLoop
-(void)startUpdatingMeter
{
    [meterUpdateDisplayLink invalidate];
    meterUpdateDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMeters)];
    [meterUpdateDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

// 停止runLoop
-(void)stopUpdatingMeter
{
    [meterUpdateDisplayLink invalidate];
    meterUpdateDisplayLink = nil;
}

#pragma mark - public method
// 开始录音
- (void)recordToPath:(NSString *)path delegate:(id<AudioToolDelegate>)delegate
{
    _delegate = delegate;
    
    if (!_flag) {
        // 初始化配置 (只能执行一次, 否则不能暂停)
        [self setupSettings:path];
        _flag = YES;
    }

    
    //-----------------------------------------------------------
    
    // Stop the audio player before recording
    if (_player.isPlaying) {
        [_player stop];
    }
    
    if (!_recorder.isRecording) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        
        // Start recording
        [_recorder record];
        
        // stackoverflow 扩大音量
        UInt32 doChangeDefault = 1;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(doChangeDefault), &doChangeDefault);
        
        // 开始runLoop
        [self startUpdatingMeter];
    }
}

// 停止录音
- (void)stopRecord
{
    [_recorder stop];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
    
    // stackoverflow 扩大音量
    [audioSession setCategory :AVAudioSessionCategoryPlayback error:nil];
    
    // 停止runLoop
    [self stopUpdatingMeter];
}

// 暂停录音
- (void)pauseRecord
{
    // Stop the audio player before recording
    if (_player.isPlaying) {
        [_player stop];
    }
    
    if (_recorder.isRecording) {
        // Pause recording
        [_recorder pause];
    }
}


// 开始播放
- (void)playWithPath:(NSString *)path delegate:(id<AudioToolDelegate>)delegate
{
    _delegate = delegate;
    
    if (!path) {
        return;
    }
    
    if (_recorder.isRecording) {
        // 正在录音的话,就先停止
        [self stopRecord];
    }
    
    if (!_recorder.isRecording) {
//        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
        _player = [[AVAudioPlayer alloc] initWithData:[NSData dataWithContentsOfFile:path] error:nil];
        _player.delegate = self;
        _player.meteringEnabled = YES;
        [_player prepareToPlay];
        [_player play];
        
        // 开始runLoop
        [self startUpdatingMeter];
    }
}

// 停止播放
- (void)stopPlayWithPath:(NSString *)path
{
    if (!path) {
        return;
    }
    
//    _player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
    _player = [[AVAudioPlayer alloc] initWithData:[NSData dataWithContentsOfFile:path] error:nil];
    _player.delegate = self;
    [_player stop];
    
    // 停止runLoop
    [self stopUpdatingMeter];
}


#pragma mark - AVAudioRecorderDelegate
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)avrecorder successfully:(BOOL)flag
{
    if (flag)
    {
        NSLog(@"录音成功");
        if ([_delegate respondsToSelector:@selector(audioTool:recordSuccess:)]) {
            [_delegate  audioTool:self recordSuccess:_recorder];
        }
    }
    else
    {
        NSLog(@"录音失败");
        if ([_delegate respondsToSelector:@selector(audioTool:recordFail:)]) {
            [_delegate  audioTool:self recordFail:_recorder];
        }
    }
    
    // 停止runLoop
    [self stopUpdatingMeter];
}

#pragma mark - AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (flag)
    {
        NSLog(@"播放成功");
        if ([_delegate respondsToSelector:@selector(audioTool:playSuccess:)]) {
            [_delegate  audioTool:self playSuccess:_player];
        }
    }
    else
    {
        NSLog(@"播放失败");
        if ([_delegate respondsToSelector:@selector(audioTool:playFail:)]) {
            [_delegate  audioTool:self playFail:_player];
        }
    }
    
    // 停止runLoop
    [self stopUpdatingMeter];
}

#pragma mark - target action
// runLoop
- (void)updateMeters
{
    if (_recorder.isRecording)
    {
        [_recorder updateMeters];
        
        CGFloat normalizedValue = pow (10, [_recorder averagePowerForChannel:0] / 20);
        
        NSLog(@"正在录音...");
        if ([_delegate respondsToSelector:@selector(audioTool:recording:normalizedValue:)]) {
            [_delegate audioTool:self recording:_recorder normalizedValue:normalizedValue];
        }
    }
    else if (_player.isPlaying)
    {
        [_player updateMeters];
        
        CGFloat normalizedValue = pow (10, [_player averagePowerForChannel:0] / 20);
        
        NSLog(@"正在播放...");
        if ([_delegate respondsToSelector:@selector(audioTool:playing:normalizedValue:)]) {
            [_delegate audioTool:self playing:_player normalizedValue:normalizedValue];
        }
    }
}

@end
