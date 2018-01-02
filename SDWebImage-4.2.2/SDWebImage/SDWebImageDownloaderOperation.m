/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageDownloaderOperation.h"
#import "SDWebImageManager.h"
#import "NSImage+WebCache.h"
#import "SDWebImageCodersManager.h"

NSString *const SDWebImageDownloadStartNotification = @"SDWebImageDownloadStartNotification";
NSString *const SDWebImageDownloadReceiveResponseNotification = @"SDWebImageDownloadReceiveResponseNotification";
NSString *const SDWebImageDownloadStopNotification = @"SDWebImageDownloadStopNotification";
NSString *const SDWebImageDownloadFinishNotification = @"SDWebImageDownloadFinishNotification";

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kCompletedCallbackKey = @"completed";

typedef NSMutableDictionary<NSString *, id> SDCallbacksDictionary;

@interface SDWebImageDownloaderOperation ()

@property (strong, nonatomic, nonnull) NSMutableArray<SDCallbacksDictionary *> *callbackBlocks;

@property (assign, nonatomic, getter = isExecuting) BOOL executing;  //是否正在执行
@property (assign, nonatomic, getter = isFinished) BOOL finished;   //是否完成
@property (strong, nonatomic, nullable) NSMutableData *imageData;   //图片二进制
@property (copy, nonatomic, nullable) NSData *cachedData;       //缓存数据

// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run
// the task associated with this operation  关联任务使用这个
@property (weak, nonatomic, nullable) NSURLSession *unownedSession;
// This is set if we're using not using an injected NSURLSession. We're responsible of invalidating this one
@property (strong, nonatomic, nullable) NSURLSession *ownedSession;

@property (strong, nonatomic, readwrite, nullable) NSURLSessionTask *dataTask;

@property (SDDispatchQueueSetterSementics, nonatomic, nullable) dispatch_queue_t barrierQueue;

#if SD_UIKIT
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;
#endif

@property (strong, nonatomic, nullable) id<SDWebImageProgressiveCoder> progressiveCoder; //图片的编码器

@end

@implementation SDWebImageDownloaderOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (nonnull instancetype)init {
    return [self initWithRequest:nil inSession:nil options:0];
}

- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(SDWebImageDownloaderOptions)options {
    if ((self = [super init])) {
        _request = [request copy];
        _shouldDecompressImages = YES;
        _options = options;
        _callbackBlocks = [NSMutableArray new];
        _executing = NO;
        _finished = NO;
        _expectedSize = 0;
        _unownedSession = session;
        _barrierQueue = dispatch_queue_create("com.hackemist.SDWebImageDownloaderOperationBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)dealloc {
    SDDispatchQueueRelease(_barrierQueue);
}


/**
 添加进度回调和完成回调

 @param progressBlock 进度回调
 @param completedBlock 完成回调
 @return 返回回调字典
 */
- (nullable id)addHandlersForProgress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                            completed:(nullable SDWebImageDownloaderCompletedBlock)completedBlock {
    SDCallbacksDictionary *callbacks = [NSMutableDictionary new];
    if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
    if (completedBlock) callbacks[kCompletedCallbackKey] = [completedBlock copy];
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks addObject:callbacks];
    });
    
    return callbacks;
}

/**
 根据key获取回调数组，其实这个方法有点🐂的  以前没注意过数组的valueForKey:这个方法，这个方法有奇效

 @param key key
 @return 回调的数组
 */
- (nullable NSArray<id> *)callbacksForKey:(NSString *)key {
    __block NSMutableArray<id> *callbacks = nil;
    dispatch_sync(self.barrierQueue, ^{
        // We need to remove [NSNull null] because there might not always be a progress block for each callback
        callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
        [callbacks removeObjectIdenticalTo:[NSNull null]];
    });
    
    return [callbacks copy];    // strip mutability here
}


- (BOOL)cancel:(nullable id)token {
    __block BOOL shouldCancel = NO;
    dispatch_barrier_sync(self.barrierQueue, ^{
        [self.callbackBlocks removeObjectIdenticalTo:token];
        if (self.callbackBlocks.count == 0) {
            shouldCancel = YES;
        }
    });
    if (shouldCancel) {
        [self cancel];
    }
    return shouldCancel;
}

/**
 重写NSOperation的start方法
 */
- (void)start {
    @synchronized (self) {
//        如果取消，重置后return
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }

#if SD_UIKIT  //后台创建Datatask
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        if (hasApplication && [self shouldContinueWhenAppEntersBackground]) {
            __weak __typeof__ (self) wself = self;
            UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong __typeof (wself) sself = wself;

                if (sself) {
                    [sself cancel];

                    [app endBackgroundTask:sself.backgroundTaskId];
                    sself.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }
#endif
        if (self.options & SDWebImageDownloaderIgnoreCachedResponse) {  //先获取缓存响应
            // Grab the cached data for later check
            NSCachedURLResponse *cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:self.request];
            if (cachedResponse) {
                self.cachedData = cachedResponse.data;
            }
        }
        
        NSURLSession *session = self.unownedSession;
        if (!self.unownedSession) {  //如果没有初始化没有传递session，创建一个session
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            
            /**
             *  Create the session for this task
             *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
             *  method calls and completion handler calls.
             */
            self.ownedSession = [NSURLSession sessionWithConfiguration:sessionConfig
                                                              delegate:self
                                                         delegateQueue:nil];
            session = self.ownedSession;
        }
        
        self.dataTask = [session dataTaskWithRequest:self.request];
        self.executing = YES;
    }
    
    [self.dataTask resume]; //开始任务

    if (self.dataTask) {  //开始的时候调用一次进度回调
        for (SDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(0, NSURLResponseUnknownLength, self.request.URL);
        }
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ //发送任务开始通知
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStartNotification object:weakSelf];
        });
    } else { //没有生产Datatask，调用完成的回调
        [self callCompletionBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Connection can't be initialized"}]];
    }

#if SD_UIKIT  //后台完成之后 取消后台任务
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
#endif
}


/**
 重写cancel
 */
- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}

- (void)cancelInternal {
//    如果任务完成，直接返回
    if (self.isFinished) return;
//    否则调用父类的取消，然后
    [super cancel];
//  如果当前的下载存在 取消，然后发出通知
    if (self.dataTask) {
        [self.dataTask cancel];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStopNotification object:weakSelf];
        });

        // As we cancelled the connection, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }
// 重置
    [self reset];
}

//  完成
- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}
//重置方法
- (void)reset {
    __weak typeof(self) weakSelf = self;
    dispatch_barrier_async(self.barrierQueue, ^{ //移除所有的回调
        [weakSelf.callbackBlocks removeAllObjects];
    });
    self.dataTask = nil; //将下载任务置空
    
//    获取DelegateQueue，然后执行图片数据置空
    NSOperationQueue *delegateQueue;
    if (self.unownedSession) {
        delegateQueue = self.unownedSession.delegateQueue;
    } else {
        delegateQueue = self.ownedSession.delegateQueue;
    }
    if (delegateQueue) {
        NSAssert(delegateQueue.maxConcurrentOperationCount == 1, @"NSURLSession delegate queue should be a serial queue");
        [delegateQueue addOperationWithBlock:^{
            weakSelf.imageData = nil;
        }];
    }
//    取消session的任务，然后置空
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent {
    return YES;
}

#pragma mark NSURLSessionDataDelegate

//NSURLSessionDataDelegate开始收到响应
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    //'304 Not Modified' is an exceptional one
    if (![response respondsToSelector:@selector(statusCode)] || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) { //正常响应
        NSInteger expected = (NSInteger)response.expectedContentLength;  //获取期望的大小
        expected = expected > 0 ? expected : 0;
        self.expectedSize = expected;
//        执行进度回调
        for (SDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(0, expected, self.request.URL);
        }
        
        self.imageData = [[NSMutableData alloc] initWithCapacity:expected]; //初始化图片数据
        self.response = response;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{    //发出通知
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadReceiveResponseNotification object:weakSelf];
        });
    } else {//不正常响应
        NSUInteger code = ((NSHTTPURLResponse *)response).statusCode;
        
        //This is the case when server returns '304 Not Modified'. It means that remote image is not changed.
        //In case of 304 we need just cancel the operation and return cached image from the cache.
//        如果返回304  就取消这个任务然后返回缓存的图片数据
        if (code == 304) {
            [self cancelInternal];
        } else {
            [self.dataTask cancel];
        }
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStopNotification object:weakSelf];
        });
        
        [self callCompletionBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain code:((NSHTTPURLResponse *)response).statusCode userInfo:nil]];

        [self done];
    }
    
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

// 开始收到数据
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.imageData appendData:data];   //拼接数据
    
    if ((self.options & SDWebImageDownloaderProgressiveDownload) && self.expectedSize > 0) { //如果Options含有SDWebImageDownloaderProgressiveDownload 并且期望大小大于0
        // Get the image data  获取图片数据
        NSData *imageData = [self.imageData copy];
        // Get the total bytes downloaded  获取下载的图片数据大小
        const NSInteger totalSize = imageData.length;
        // Get the finish status  判断是否下载完成
        BOOL finished = (totalSize >= self.expectedSize);
        
        if (!self.progressiveCoder) {   //创建一个图片编码器，根据进度编码图片
            // We need to create a new instance for progressive decoding to avoid conflicts
            for (id<SDWebImageCoder>coder in [SDWebImageCodersManager sharedInstance].coders) {
                if ([coder conformsToProtocol:@protocol(SDWebImageProgressiveCoder)] &&
                    [((id<SDWebImageProgressiveCoder>)coder) canIncrementallyDecodeFromData:imageData]) {
                    self.progressiveCoder = [[[coder class] alloc] init];
                    break;
                }
            }
        }
        
        UIImage *image = [self.progressiveCoder incrementallyDecodedImageWithData:imageData finished:finished];  //解码器解码二进制变成图片
        if (image) {
            NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];  //根据请求的url获取缓存的key  一般是url的绝对字符串
            image = [self scaledImageForKey:key image:image];   //根据key对图片进行比例变化
            if (self.shouldDecompressImages) { //解压缩图片
                image = [[SDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&data options:@{SDWebImageCoderScaleDownLargeImagesKey: @(NO)}];
            }
//            解码成图片调用一次完成回调,但是没有真正的请求完成
            [self callCompletionBlocksWithImage:image imageData:nil error:nil finished:NO];
        }
    }
//    回调进度
    for (SDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
        progressBlock(self.imageData.length, self.expectedSize, self.request.URL);
    }
}

//  即将进行缓存，通过调用completionHandler进行缓存
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    
    NSCachedURLResponse *cachedResponse = proposedResponse;
//    如果缓存策略是忽略本地的缓存，将本地的缓存响应置空
    if (self.request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData) {
        // Prevents caching of responses
        cachedResponse = nil;
    }
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}

#pragma mark NSURLSessionTaskDelegate

// 下载task完成
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    @synchronized(self) {
        self.dataTask = nil;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ //发出通知
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStopNotification object:weakSelf];
            if (!error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadFinishNotification object:weakSelf];
            }
        });
    }
    
    if (error) { //出现错误  发出完成回调
        [self callCompletionBlocksWithError:error];
    } else {
        if ([self callbacksForKey:kCompletedCallbackKey].count > 0) {
            /**
             *  If you specified to use `NSURLCache`, then the response you get here is what you need.
             */
            NSData *imageData = [self.imageData copy];
            if (imageData) {
                /**  if you specified to only use cached data via `SDWebImageDownloaderIgnoreCachedResponse`,
                 *  then we should check if the cached data is equal to image data
                 * 如果使用缓存选项SDWebImageDownloaderIgnoreCachedResponse，本地应该没有缓存，如果有缓存说明出现错误
                 */
                if (self.options & SDWebImageDownloaderIgnoreCachedResponse && [self.cachedData isEqualToData:imageData]) {
                    // call completion block with nil 如果缓存数据和图片数据相等，完成回调全部使用nil
                    [self callCompletionBlocksWithImage:nil imageData:nil error:nil finished:YES];
                } else {
                    UIImage *image = [[SDWebImageCodersManager sharedInstance] decodedImageWithData:imageData];  //将图片数据解码成图片
                    NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];   //获取缓存key
                    image = [self scaledImageForKey:key image:image];   //根据缓存名，对图片进行比例变化
                    
                    BOOL shouldDecode = YES; //是否解码图片
                    // Do not force decoding animated GIFs and WebPs   对于GIFs和WebPs不进行解码
                    if (image.images) {
                        shouldDecode = NO;
                    } else {
#ifdef SD_WEBP
                        SDImageFormat imageFormat = [NSData sd_imageFormatForImageData:imageData];  //获取图片格式
                        if (imageFormat == SDImageFormatWebP) {
                            shouldDecode = NO;
                        }
#endif
                    }
                    
                    if (shouldDecode) {  //如果需要解码
                        if (self.shouldDecompressImages) { //是否需要解压缩
                            BOOL shouldScaleDown = self.options & SDWebImageDownloaderScaleDownLargeImages; //是否需要大图
                            image = [[SDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&imageData options:@{SDWebImageCoderScaleDownLargeImagesKey: @(shouldScaleDown)}]; //解压缩图片
                        }
                    }
                    if (CGSizeEqualToSize(image.size, CGSizeZero)) { //图片的大小和CGSizeZero比较  相等  回调错误
//                        [self callCompletionBlocksWithImage:image imageData:imageData error:nil finished:YES];
                        [self callCompletionBlocksWithError:[NSError errorWithDomain:SDWebImageErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Downloaded image has 0 pixels"}]];
                    } else { //正确的回调
                        [self callCompletionBlocksWithImage:image imageData:imageData error:nil finished:YES];
                    }
                }
            } else {
                [self callCompletionBlocksWithError:[NSError errorWithDomain:SDWebImageErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Image data is nil"}]];
            }
        }
    }
    [self done];
}

// 身份验证
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
//    如果是服务器返回的授权质问保护区域是服务器信任
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (!(self.options & SDWebImageDownloaderAllowInvalidSSLCertificates)) { //如果Options不包含SDWebImageDownloaderAllowInvalidSSLCertificates，采用默认处理方法
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        } else {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            disposition = NSURLSessionAuthChallengeUseCredential;
        }
    } else {
        if (challenge.previousFailureCount == 0) {
            if (self.credential) {
                credential = self.credential;
                disposition = NSURLSessionAuthChallengeUseCredential;
            } else {
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

#pragma mark Helper methods
- (nullable UIImage *)scaledImageForKey:(nullable NSString *)key image:(nullable UIImage *)image {
    return SDScaledImageForKey(key, image);
}

//  是否需要后台下载
- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & SDWebImageDownloaderContinueInBackground;
}

- (void)callCompletionBlocksWithError:(nullable NSError *)error {
    [self callCompletionBlocksWithImage:nil imageData:nil error:error finished:YES];
}

- (void)callCompletionBlocksWithImage:(nullable UIImage *)image
                            imageData:(nullable NSData *)imageData
                                error:(nullable NSError *)error
                             finished:(BOOL)finished {
    NSArray<id> *completionBlocks = [self callbacksForKey:kCompletedCallbackKey];
    dispatch_main_async_safe(^{
        for (SDWebImageDownloaderCompletedBlock completedBlock in completionBlocks) {
            completedBlock(image, imageData, error, finished);
        }
    });
}

@end
