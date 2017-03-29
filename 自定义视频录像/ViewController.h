//
//  ViewController.h
//  自定义视频录像
//
//  Created by liman on 15/10/19.
//  Copyright © 2015年 liman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RecordVideoController.h"
#import "UIAlertView+Utils.h"
#import "StatusBarTool.h"

@interface ViewController : UIViewController <RecordVideoControllerDelegate>

@property (strong, nonatomic) ALAssetsLibrary *assetsLibrary;

@end

