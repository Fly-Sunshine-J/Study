/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCoder.h"

/**
 Built in coder that supports PNG, JPEG, TIFF, includes support for progressive decoding.
 
 GIF
 Also supports static GIF (meaning will only handle the 1st frame).
 For a full GIF support, we recommend `FLAnimatedImage` or our less performant `SDWebImageGIFCoder`
 
 HEIC
 This coder also supports HEIC format because ImageIO supports it natively. But it depends on the system capabilities, so it won't work on all devices.
 Hardware works if:  (iOS 11 || macOS 10.13) && (isMac || isIPhoneAndA10FusionChipAbove) && (!Simulator)
 这个解码器支持 PNG，JPEG，TIFF，支持进度解码，
 支持静态的GIF，就是动图的第一帧，如果是真正的GIF图片  建议使用FLAnimatedImage
 支持HEIC格式的图片
 */
@interface SDWebImageImageIOCoder : NSObject <SDWebImageProgressiveCoder>

+ (nonnull instancetype)sharedCoder;

@end
