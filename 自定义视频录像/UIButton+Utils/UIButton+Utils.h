//
//  UIButton+Utils.h
//  silu
//
//  Created by liman on 15/4/11.
//  Copyright (c) 2015年 upintech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UIButton (Utils)

/**
 *  扩大按钮点击区域
 */
- (void)setEnlargeEdge:(CGFloat) size;
/**
 *  扩大按钮点击区域
 */
- (void)setEnlargeEdgeWithTop:(CGFloat) top right:(CGFloat) right bottom:(CGFloat) bottom left:(CGFloat) left;

@end
