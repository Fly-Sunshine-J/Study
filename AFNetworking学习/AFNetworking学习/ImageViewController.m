//
//  ImageViewController.m
//  AFNetworking学习
//
//  Created by vcyber on 2017/11/16.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "ImageViewController.h"
#import <CoreGraphics/CoreGraphics.h>

@interface ImageViewController ()

@end

@implementation ImageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    UIImageView *imageview = [[UIImageView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    [self.view addSubview:imageview];

    UIImage *image = [UIImage imageNamed:@"001"];
    imageview.image = image;

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
