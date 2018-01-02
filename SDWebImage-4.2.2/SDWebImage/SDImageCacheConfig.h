/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

@interface SDImageCacheConfig : NSObject

/**
 * 是否压缩图片进行， 默认YES
 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 * iCloud进行备份是否不可用，默认YES，不支持备份
 */
@property (assign, nonatomic) BOOL shouldDisableiCloud;

/**
 * 是否使用内存缓存，默认YES
 */
@property (assign, nonatomic) BOOL shouldCacheImagesInMemory;

/**
 * 当读取磁盘缓存option，默认是0，你可以设置它使文件映射提高效率
 */
@property (assign, nonatomic) NSDataReadingOptions diskCacheReadingOptions;

/**
 * 磁盘缓存保留的最长时间，单位是秒，默认是一周
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * 磁盘缓存所占的内存最大值，默认是0
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

@end
