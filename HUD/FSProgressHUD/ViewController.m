//
//  ViewController.m
//  FSProgressHUD
//
//  Created by vcyber on 2017/10/30.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "ViewController.h"
#import "FSProgressHUD.h"


@interface ViewController () {
    FSProgressHUD *_hud;
}


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor greenColor];
   
    FSProgressHUD *hud = [[FSProgressHUD alloc] initWithView:self.view];
    hud.titleLabel.text = @"正在加载...哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈22哈";
    hud.detailLbael.text = @"哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈22哈哈哈哈哈哈哈哈哈";
    [hud.button setTitle:@"取消哈哈哈哈" forState:UIControlStateNormal];
    [hud.button addTarget:self action:@selector(didReceiveMemoryWarning) forControlEvents:UIControlEventTouchUpInside];
    hud.animationType = FSProgressHUDAnimationZoom;
    _hud = hud;
}



- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    static int a = 0;
    
    if (a % 2 == 0) {
        [_hud showAnimated:YES];
    }else {
        [_hud hideAnimated:YES];
    }
    a++;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
