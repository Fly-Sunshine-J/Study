/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
#import "SDImageCacheConfig.h"


/**
 缓存的类型，不需要缓存，磁盘缓存，内存缓存
 */
typedef NS_ENUM(NSInteger, SDImageCacheType) {
    /**
     * 图片不在缓存中获取，直接从web上获取
     */
    SDImageCacheTypeNone,
    /**
     * 图片可以在磁盘中缓存
     */
    SDImageCacheTypeDisk,
    /**
     * 图片在内存中缓存
     */
    SDImageCacheTypeMemory
};

typedef void(^SDCacheQueryCompletedBlock)(UIImage * _Nullable image, NSData * _Nullable data, SDImageCacheType cacheType);

typedef void(^SDWebImageCheckCacheCompletionBlock)(BOOL isInCache);

typedef void(^SDWebImageCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);


/**
 * SDImageCache maintains a memory cache and an optional disk cache. Disk cache write operations are performed
 * asynchronous so it doesn’t add unnecessary latency to the UI.
 * SDImageCache维护一个内存缓存和一个可选的磁盘缓存，磁盘缓存的写入操作是一个异步的操作，不会影响主线程
 */
@interface SDImageCache : NSObject

#pragma mark - Properties

/**
 *  SDImageCacheConfig实例，保存设置
 */
@property (nonatomic, nonnull, readonly) SDImageCacheConfig *config;

/**
 * 内存缓存的最大值
 * The maximum "total cost" of the in-memory image cache. The cost function is the number of pixels held in memory.
 */
@property (assign, nonatomic) NSUInteger maxMemoryCost;

/**
 * 最大的内存缓存数量限制
 * The maximum number of objects the cache should hold.
 */
@property (assign, nonatomic) NSUInteger maxMemoryCountLimit;

#pragma mark - Singleton and initialization

/**
 * Returns global shared cache instance
 * 获取一个全局的单例缓存实例
 * @return SDImageCache global instance
 */
+ (nonnull instancetype)sharedImageCache;

/**
 * Init a new cache store with a specific namespace
 * 使用一个特殊的命名空间创建一个缓存实例
 * @param ns The namespace to use for this cache store
 */
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns;

/**
 * Init a new cache store with a specific namespace and directory
 * 使用一个特殊的命名空间和一个存盘缓存文件创建一个缓存实例
 * @param ns        The namespace to use for this cache store
 * @param directory Directory to cache disk images in
 */
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nonnull NSString *)directory NS_DESIGNATED_INITIALIZER;

#pragma mark - Cache paths

//   根据命名空间创建一个磁盘缓存路径
- (nullable NSString *)makeDiskCachePath:(nonnull NSString*)fullNamespace;

/**
 * Add a read-only cache path to search for images pre-cached by SDImageCache
 * Useful if you want to bundle pre-loaded images with your app
 * 添加一个只读的缓存路径用于SDImageCache搜索预缓存的图片
 * @param path The path to use for this read-only cache path
 */
- (void)addReadOnlyCachePath:(nonnull NSString *)path;

#pragma mark - Store Ops

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 * 用一个key异步存储一个图片到内存和磁盘中。
 * @param image           The image to store   需要存储的图片
 * @param key             The unique image cache key, usually it's image absolute URL 唯一的图片缓存key，一般使用图片的url的绝对路径
 * @param completionBlock A block executed after the operation is finished   完成的回调
 */
- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 * 用一个key异步存储一个图片到内存和磁盘中。
 * @param image           The image to store  需要存储的图片
 * @param key             The unique image cache key, usually it's image absolute URL  图片缓存的key
 * @param toDisk          Store the image to disk cache if YES  是否需要存储在磁盘中
 * @param completionBlock A block executed after the operation is finished  完成的回调
 */
- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 * 用一个key异步存储一个图片到内存和磁盘中。
 * @param image           The image to store 需要存储的图片
 * @param imageData       The image data as returned by the server, this representation will be used for disk storage instead of converting the given image object into a storable/compressed image format in order to save quality and CPU  服务器返回的图片二进制，用于磁盘的存储，这样就不需要将图片转化成一个可存储的或者压缩的图片格式，这样可以提高保存质量和CPU效率
 * @param key             The unique image cache key, usually it's image absolute URL  图片缓存的key
 * @param toDisk          Store the image to disk cache if YES  是否存储到磁盘
 * @param completionBlock A block executed after the operation is finished  完成的回调
 */
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Synchronously store image NSData into disk cache at the given key.
 * 使用一个key异步的将图片的二进制缓存到磁盘
 * @warning This method is synchronous, make sure to call it from the ioQueue
 *
 * @param imageData  The image data to store
 * @param key        The unique image cache key, usually it's image absolute URL
 */
- (void)storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key;

#pragma mark - Query and Retrieve Ops

/**
 *  Async check if image exists in disk cache already (does not load the image)
 *  根据key异步检查图片是否已经在磁盘缓存中，不是加载图片
 *  @param key             the key describing the url
 *  @param completionBlock the block to be executed when the check is done.
 *  @note the completion block will be always executed on the main queue
 */
- (void)diskImageExistsWithKey:(nullable NSString *)key completion:(nullable SDWebImageCheckCacheCompletionBlock)completionBlock;

/**
 * Operation that queries the cache asynchronously and call the completion when done.
 * 根据图片的缓存key和一个完成回调创建一个NSOperation，用于异步操作使用，如果op取消，回到将不会被调用
 * @param key       The unique key used to store the wanted image
 * @param doneBlock The completion block. Will not get called if the operation is cancelled
 *
 * @return a NSOperation instance containing the cache op
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key done:(nullable SDCacheQueryCompletedBlock)doneBlock;

/**
 * Query the memory cache synchronously.
 * 根据图片内存缓存的key异步查询图片
 * @param key The unique key used to store the image
 */
- (nullable UIImage *)imageFromMemoryCacheForKey:(nullable NSString *)key;

/**
 * Query the disk cache synchronously.
 * 根据图片磁盘缓存的key异步查询图片
 * @param key The unique key used to store the image
 */
- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key;

/**
 * Query the cache (memory and or disk) synchronously after checking the memory cache.
 * 异步的检查内存缓存之后根据缓存图片的key查询内存或者磁盘缓存
 * @param key The unique key used to store the image
 */
- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key;

#pragma mark - Remove Ops

/**
 * Remove the image from memory and disk cache asynchronously
 * 异步的从内存和磁盘中移除图片
 * @param key             The unique image cache key
 * @param completion      A block that should be executed after the image has been removed (optional)
 */
- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable SDWebImageNoParamsBlock)completion;

/**
 * Remove the image from memory and optionally disk cache asynchronously
 * 异步的从内存和一个可选的磁盘中移除图片
 * @param key             The unique image cache key   图片缓存的key
 * @param fromDisk        Also remove cache entry from disk if YES  是否从磁盘中移除
 * @param completion      A block that should be executed after the image has been removed (optional)
 */
- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable SDWebImageNoParamsBlock)completion;

#pragma mark - Cache clean Ops

/**
 * Clear all memory cached images
 * 清理所有的内存缓存
 */
- (void)clearMemory;

/**
 * Async clear all disk cached images. Non-blocking method - returns immediately.
 * 异步清理所有磁盘的缓存
 * @param completion    A block that should be executed after cache expiration completes (optional)
 */
- (void)clearDiskOnCompletion:(nullable SDWebImageNoParamsBlock)completion;

/**
 * Async remove all expired cached image from disk. Non-blocking method - returns immediately.
 * 异步清理过期的磁盘缓存数据
 * @param completionBlock A block that should be executed after cache expiration completes (optional)
 */
- (void)deleteOldFilesWithCompletionBlock:(nullable SDWebImageNoParamsBlock)completionBlock;

#pragma mark - Cache Info

/**
 * Get the size used by the disk cache
 * 获取磁盘缓存数据的大小
 */
- (NSUInteger)getSize;

/**
 * Get the number of images in the disk cache
 * 获取缓存图片的数量
 */
- (NSUInteger)getDiskCount;

/**
 * Asynchronously calculate the disk cache's size.
 * 异步计算磁盘缓存的大小和磁盘缓存图片的数量
 */
- (void)calculateSizeWithCompletionBlock:(nullable SDWebImageCalculateSizeBlock)completionBlock;

#pragma mark - Cache Paths

/**
 *  Get the cache path for a certain key (needs the cache path root folder)
 *  根据一个缓存的key和图片所在的文件夹路径获取完整的缓存路径
 *  @param key  the key (can be obtained from url using cacheKeyForURL)
 *  @param path the cache path root folder
 *
 *  @return the cache path
 */
- (nullable NSString *)cachePathForKey:(nullable NSString *)key inPath:(nonnull NSString *)path;

/**
 *  Get the default cache path for a certain key
 *  根据一个缓存的key获取默认的完整的缓存路径
 *  @param key the key (can be obtained from url using cacheKeyForURL)
 *
 *  @return the default cache path
 */
- (nullable NSString *)defaultCachePathForKey:(nullable NSString *)key;

@end
