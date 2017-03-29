//
//  StatusBarTool.m
//  silu
//
//  Created by liman on 3/6/15.
//  Copyright (c) 2015年 upintech. All rights reserved.
//
#define SHARED_APPLICATION [UIApplication sharedApplication]

#import "StatusBarTool.h"

@implementation StatusBarTool

+ (StatusBarTool *)sharedInstance
{
    static StatusBarTool *__singletion = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        __singletion = [[self alloc] init];
        
    });
    
    return __singletion;
}

/**
 *  隐藏状态栏
 */
- (void)hideStatusBar
{
    [SHARED_APPLICATION setStatusBarHidden:YES];
}

/**
 *  显示状态栏
 */
- (void)showStatusBar
{
    [SHARED_APPLICATION setStatusBarHidden:NO];
}

/**
 *  设置状态栏文字为白色
 */
- (void)setStatusBarWhite
{
    [SHARED_APPLICATION setStatusBarStyle:UIStatusBarStyleLightContent];
}

/**
 *  设置状态栏文字为黑色
 */
- (void)setStatusBarBlack
{
    [SHARED_APPLICATION setStatusBarStyle:UIStatusBarStyleDefault];
}

@end
