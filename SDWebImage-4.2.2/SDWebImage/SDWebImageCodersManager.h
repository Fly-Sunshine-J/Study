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
 Global object holding the array of coders, so that we avoid passing them from object to object.
 Uses a priority queue behind scenes, which means the latest added coders have the highest priority.
 This is done so when encoding/decoding something, we go through the list and ask each coder if they can handle the current data.
 That way, users can add their custom coders while preserving our existing prebuilt ones
 
 Note: the `coders` getter will return the coders in their reversed order
 Example:
 - by default we internally set coders = `IOCoder`, `WebPCoder`. (`GIFCoder` is not recommended to add only if you want to get GIF support without `FLAnimatedImage`)
 - calling `coders` will return `@[WebPCoder, IOCoder]`
 - call `[addCoder:[MyCrazyCoder new]]`
 - calling `coders` now returns `@[MyCrazyCoder, WebPCoder, IOCoder]`
 
 Coders
 ------
 A coder must conform to the `SDWebImageCoder` protocol or even to `SDWebImageProgressiveCoder` if it supports progressive decoding
 Conformance is important because that way, they will implement `canDecodeFromData` or `canEncodeToFormat`
 Those methods are called on each coder in the array (using the priority order) until one of them returns YES.
 That means that coder can decode that data / encode to that format
 图片解码器的管理器，默认的管理器里面只有两种解码器IOCoder和WebPCoder，，新加入的解码器具有更高的优先级去解码图片
 */
@interface SDWebImageCodersManager : NSObject<SDWebImageCoder>

/**
 Shared reusable instance
 单例，默认的解码管理器
 */
+ (nonnull instancetype)sharedInstance;

/**
 All coders in coders manager. The coders array is a priority queue, which means the later added coder will have the highest priority
 解码管理器中的解码器，新加入的优先级更高
 */
@property (nonatomic, strong, readwrite, nullable) NSArray<SDWebImageCoder>* coders;

/**
 Add a new coder to the end of coders array. Which has the highest priority.
 添加一个新的解码器到解码器管理器中
 @param coder coder
 */
- (void)addCoder:(nonnull id<SDWebImageCoder>)coder;

/**
 Remove a coder in the coders array.
 移除一个解码器
 @param coder coder
 */
- (void)removeCoder:(nonnull id<SDWebImageCoder>)coder;

@end
