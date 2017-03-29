//
//  UIView+Utils.h
//  silu
//
//  Created by liman on 24/4/15.
//  Copyright (c) 2015年 upintech. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (Utils)

- (void)removeAllSubviews;

// 设置圆角
-(void)makeCornerRadius:(float)radius borderColor:(UIColor*)bColor borderWidth:(float)bWidth;

/**
 *  设置一边圆角
 */
- (UIView *)roundCornersOnView:(UIView *)view onTopLeft:(BOOL)tl topRight:(BOOL)tr bottomLeft:(BOOL)bl bottomRight:(BOOL)br radius:(float)radius;

@end
