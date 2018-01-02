/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageGIFCoder.h"
#import "NSImage+WebCache.h"
#import <ImageIO/ImageIO.h>
#import "NSData+ImageContentType.h"
#import "UIImage+MultiFormat.h"
#import "SDWebImageCoderHelper.h"

@implementation SDWebImageGIFCoder

+ (instancetype)sharedCoder {
    static SDWebImageGIFCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[SDWebImageGIFCoder alloc] init];
    });
    return coder;
}

#pragma mark - Decode
- (BOOL)canDecodeFromData:(nullable NSData *)data {
    return ([NSData sd_imageFormatForImageData:data] == SDImageFormatGIF);
}

- (UIImage *)decodedImageWithData:(NSData *)data {
    if (!data) {
        return nil;
    }
    
#if SD_MAC
    return [[UIImage alloc] initWithData:data];
#else
//    根据二进制获取CGImageSourceRef
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return nil;
    }
//    获取CGImageSourceRef的帧数
    size_t count = CGImageSourceGetCount(source);
    
    UIImage *animatedImage;
    
//    如果帧数小于1，直接生产图片
    if (count <= 1) {
        animatedImage = [[UIImage alloc] initWithData:data];
    } else {  //获取帧数
        NSMutableArray<SDWebImageFrame *> *frames = [NSMutableArray array];
        
        for (size_t i = 0; i < count; i++) {
//            获取某一帧的CGImageRef
            CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, i, NULL);
            if (!imageRef) {
                continue;
            }
//            获取某一帧的动画时间
            float duration = [self sd_frameDurationAtIndex:i source:source];
//            获取比例
#if SD_WATCH
            CGFloat scale = 1;
            scale = [WKInterfaceDevice currentDevice].screenScale;
#elif SD_UIKIT
            CGFloat scale = 1;
            scale = [UIScreen mainScreen].scale;
#endif
//            生成图片
            UIImage *image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
            CGImageRelease(imageRef);
//            生成SDWebImageFrame对象
            SDWebImageFrame *frame = [SDWebImageFrame frameWithImage:image duration:duration];
            [frames addObject:frame];
        }

        NSUInteger loopCount = 0;
//        获取CGImageSourceRef的属性
        NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(source, nil);
//        获取gif图片属性字典
        NSDictionary *gifProperties = [imageProperties valueForKey:(__bridge_transfer NSString *)kCGImagePropertyGIFDictionary];
//        获取gif图循环次数
        if (gifProperties) {
            NSNumber *gifLoopCount = [gifProperties valueForKey:(__bridge_transfer NSString *)kCGImagePropertyGIFLoopCount];
            if (gifLoopCount) {
                loopCount = gifLoopCount.unsignedIntegerValue;
            }
        }
//        生成动图
        animatedImage = [SDWebImageCoderHelper animatedImageWithFrames:frames];
        animatedImage.sd_imageLoopCount = loopCount;
    }
    
    CFRelease(source);
    
    return animatedImage;
#endif
}

- (float)sd_frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source {
    float frameDuration = 0.1f;
//    获取某一帧的属性
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil);
    NSDictionary *frameProperties = (__bridge NSDictionary *)cfFrameProperties;
//    获取GIF图片的属性字典
    NSDictionary *gifProperties = frameProperties[(NSString *)kCGImagePropertyGIFDictionary];
//    获取开放的时间
    NSNumber *delayTimeUnclampedProp = gifProperties[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
    if (delayTimeUnclampedProp) {
        frameDuration = [delayTimeUnclampedProp floatValue];
    } else {
//        如果获取不到 获取延迟时间
        NSNumber *delayTimeProp = gifProperties[(NSString *)kCGImagePropertyGIFDelayTime];
        if (delayTimeProp) {
            frameDuration = [delayTimeProp floatValue];
        }
    }
    
    // Many annoying ads specify a 0 duration to make an image flash as quickly as possible.
    // We follow Firefox's behavior and use a duration of 100 ms for any frames that specify
    // a duration of <= 10 ms. See <rdar://problem/7689300> and <http://webkit.org/b/36082>
    // for more information.
//    如果获取的时间小于10ms  将时间设置为100ms
    if (frameDuration < 0.011f) {
        frameDuration = 0.100f;
    }
    
    CFRelease(cfFrameProperties);
    return frameDuration;
}

- (UIImage *)decompressedImageWithImage:(UIImage *)image
                                   data:(NSData *__autoreleasing  _Nullable *)data
                                options:(nullable NSDictionary<NSString*, NSObject*>*)optionsDict {
    // GIF do not decompress
    return image;
}

#pragma mark - Encode
- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    return (format == SDImageFormatGIF);
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(SDImageFormat)format {
    if (!image) {
        return nil;
    }
    
    if (format != SDImageFormatGIF) {
        return nil;
    }
    
    NSMutableData *imageData = [NSMutableData data];
    CFStringRef imageUTType = [NSData sd_UTTypeFromSDImageFormat:SDImageFormatGIF];
//    根据动图获取帧数
    NSArray<SDWebImageFrame *> *frames = [SDWebImageCoderHelper framesFromAnimatedImage:image];
    
    // Create an image destination. GIF does not support EXIF image orientation
//    创建目标图像CGImageDestinationRef
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, frames.count, NULL);
    if (!imageDestination) {
        // Handle failure.
        return nil;
    }
    if (frames.count == 0) {
        // for static single GIF images 如果是静态的GIF图，添加进去即可
        CGImageDestinationAddImage(imageDestination, image.CGImage, nil);
    } else {
        // for animated GIF images
//        给目标图像设置属性字典，设置循环次数
        NSUInteger loopCount = image.sd_imageLoopCount;
        NSDictionary *gifProperties = @{(__bridge_transfer NSString *)kCGImagePropertyGIFDictionary: @{(__bridge_transfer NSString *)kCGImagePropertyGIFLoopCount : @(loopCount)}};
        CGImageDestinationSetProperties(imageDestination, (__bridge CFDictionaryRef)gifProperties);
        
//        将每一帧的图片加入到目标图像中
        for (size_t i = 0; i < frames.count; i++) {
            SDWebImageFrame *frame = frames[i];
            float frameDuration = frame.duration;
            CGImageRef frameImageRef = frame.image.CGImage;
            NSDictionary *frameProperties = @{(__bridge_transfer NSString *)kCGImagePropertyGIFDictionary : @{(__bridge_transfer NSString *)kCGImagePropertyGIFUnclampedDelayTime : @(frameDuration)}};
            CGImageDestinationAddImage(imageDestination, frameImageRef, (__bridge CFDictionaryRef)frameProperties);
        }
    }
    // Finalize the destination.  完成目标图像
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        // Handle failure.
        imageData = nil;
    }
    
    CFRelease(imageDestination);
    
    return [imageData copy];
}

@end
