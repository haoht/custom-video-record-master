//
//  ViewController.m
//  自定义视频录像
//
//  Created by liman on 15/10/19.
//  Copyright © 2015年 liman. All rights reserved.
//
#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, SCREEN_WIDTH, 40)];
    label.text = @"just click";
    label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:label];
    

    if (!_assetsLibrary) {
        _assetsLibrary = [ALAssetsLibrary new];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    RecordVideoController *vc = [RecordVideoController new];
    vc.delegate = self;
    [self presentViewController:vc animated:YES completion:nil];
}


#pragma mark - RecordVideoControllerDelegate
// 获取录制的视频文件的路径
- (void)recordVideoController:(RecordVideoController *)picker didFinishPickingVideoURL:(NSURL *)videoUrl
{
    // 1.保存视频到相册
    [_assetsLibrary writeVideoAtPathToSavedPhotosAlbum:videoUrl completionBlock:^(NSURL *assetURL, NSError *error) {
        
        if (!error)
        {
            NSLog(@"视频保存成功");
            
            // 2.获取视频截图
            [_assetsLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
                
                UIImage *videoShotImage = [UIImage imageWithCGImage:asset.defaultRepresentation.fullResolutionImage
                                                              scale:asset.defaultRepresentation.scale
                                                        orientation:(UIImageOrientation)asset.defaultRepresentation.orientation];
                
                // 3.跳转到NewPost控制器
                /*
                GCD_SYSTEM_MAIN(^{
                    NewPostController *post = [[NewPostController alloc] initWithLocalMediaWithImages:nil audioPath:nil videoURL:videoUrl videoShotImage:videoShotImage];
                    post.delegate = self;
                    UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:post];
                    [self presentViewController:navi animated:YES completion:nil];
                });
                 */
                [UIAlertView showWithMessage:@"视频已保存到系统相册"];
                
            } failureBlock:^(NSError *error) {
                [UIAlertView showWithMessage:@"视频保存失败"];
            }];
        }
        else
        {
            [UIAlertView showWithMessage:@"视频保存失败"];
        }
    }];
    
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
