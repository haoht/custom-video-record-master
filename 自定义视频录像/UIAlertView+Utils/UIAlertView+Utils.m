//
//  UIAlertView+Utils.m
//  1worldtrip
//
//  Created by liman on 11/5/15.
//  Copyright (c) 2015年 upintech. All rights reserved.
//

#import "UIAlertView+Utils.h"

@implementation UIAlertView (Utils)

+ (void)showWithMessage:(NSString *)message
{
    [[[self alloc] initWithTitle:@"" message:message delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] show];
}

@end
