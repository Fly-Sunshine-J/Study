//
//  AppDelegate.m
//  AFNetworking学习
//
//  Created by vcyber on 2017/11/7.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    return YES;
}


- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler {
    if ([identifier isEqualToString:@"cyw"]) {
        NSLog(@"aaaa");
        _completeHandle = completionHandler;
    }
}


@end
