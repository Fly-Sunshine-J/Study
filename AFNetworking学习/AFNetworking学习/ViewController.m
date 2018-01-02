//
//  ViewController.m
//  AFNetworking学习
//
//  Created by vcyber on 2017/11/7.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "ViewController.h"
#import "AFNetworking.h"
#import "AppDelegate.h"
#import "ImageViewController.h"


@interface AFModel:NSObject
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSString *controller;
+ (instancetype)modelWithType:(NSString *)type controller:(NSString *)controller;
@end

@implementation AFModel
+ (instancetype)modelWithType:(NSString *)type controller:(NSString *)controller {
    AFModel *model = [[AFModel alloc] init];
    model.type = type;
    model.controller = controller;
    return model;
}
@end

@interface ViewController ()

@property (nonatomic, strong) NSMutableArray<AFModel *> *dataArray;
@property (nonatomic, strong) NSData *resumeData;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];


    UITableView *tableView = (UITableView *)self.view;
    tableView.tableFooterView = [UIView new];
    
    //MARK: -AFURLSessionManager
    [self addModelWithType:@"请求数据" controller:@"aaa"];
    NSString *key = nil;
    NSLog(@"%@", [NSString stringWithFormat:@"%@[]", key]);
 
}



- (void)addModelWithType:(NSString *)type controller:(NSString *)controller {
    AFModel *model = [AFModel modelWithType:type controller:controller];
    [self.dataArray addObject:model];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _dataArray.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CELL" forIndexPath:indexPath];
    cell.textLabel.text = _dataArray[indexPath.row].type;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
//    [[AFHTTPSessionManager manager] GET:@"http://api.dantangapp.com/v1/channels/4/items?gender=1&generation=1&limit=20&offset=0" parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
//
//    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//
//    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//
//    }];
//    AFURLSessionManager *m = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];//https://192.168.100.182/MicrosoftWord.app.zip
//    m.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModePublicKey];
//    m.securityPolicy.allowInvalidCertificates = YES;
//    NSURLSessionDownloadTask *task = [m downloadTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com/"]] progress:^(NSProgress * _Nonnull downloadProgress) {
//        NSLog(@"%f", downloadProgress.fractionCompleted);
//    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
//        NSString  *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/a.xip"];
//        return [NSURL fileURLWithPath:path];
//    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
//        NSLog(@"complete  %@ -- error: %@", filePath, error);
//    }];
//    [task resume];
//
//    [m setDidFinishEventsForBackgroundURLSessionBlock:^(NSURLSession * _Nonnull session) {
//        NSLog(@"ccccc");
//        [(AppDelegate *)[UIApplication sharedApplication].delegate completeHandle]();
//    }];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
//            self.resumeData = resumeData;
//            [resumeData writeToFile:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/a.plist"] atomically:YES] ;
//        }];
//    });
//
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        NSData *data = self.resumeData;
//        self.resumeData = nil;
//        NSURLSessionDownloadTask *task1 = [m downloadTaskWithResumeData:data progress:^(NSProgress * _Nonnull downloadProgress) {
//            NSLog(@"%f", downloadProgress.fractionCompleted);
//        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
//            NSString  *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/a.mp4"];
//            return [NSURL fileURLWithPath:path];
//        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
//            NSLog(@"resume complete %@", filePath);
//        }];
//        [task1 resume];
//    });
    
    [self http];
    
    [self.navigationController pushViewController:[[ImageViewController alloc] init] animated:YES];
    
    
}

- (void)http {
//    [[AFHTTPSessionManager manager] POST:@"http://192.168.100.182/MicrosoftWord.app.zip" parameters:@{@"a":@"aa"} progress:^(NSProgress * _Nonnull downloadProgress) {
//
//    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//
//    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//
//    }];
//    [[AFHTTPSessionManager manager] setSecurityPolicy:[AFSecurityPolicy policyWithPinningMode:AFSSLPinningModePublicKey]];
//    [[AFHTTPSessionManager manager] POST:@"http://192.168.100.182/" parameters:@{@"aa":@"bb"} constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
//        [formData appendPartWithFormData:[@"bbbb" dataUsingEncoding:NSUTF8StringEncoding] name:@"ccc"];
//    } progress:^(NSProgress * _Nonnull uploadProgress) {
//
//    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//
//    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//
//    }];
    
    [[AFHTTPSessionManager manager] POST:@"http://192.168.100.182/" parameters:@{@"aa":@"bb"} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
    
}




- (NSMutableArray *)dataArray {
    if (!_dataArray) {
        _dataArray = [NSMutableArray array];
    }
    return _dataArray;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
