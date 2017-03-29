//
//  StatusBarTool.h
//  silu
//
//  Created by liman on 3/6/15.
//  Copyright (c) 2015年 upintech. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface StatusBarTool : NSObject

+ (StatusBarTool *)sharedInstance;

/**
 *  隐藏状态栏
 */
- (void)hideStatusBar;

/**
 *  显示状态栏
 */
- (void)showStatusBar;

/**
 *  设置状态栏文字为白色
 */
- (void)setStatusBarWhite;

/**
 *  设置状态栏文字为黑色
 */
- (void)setStatusBarBlack;

@end
