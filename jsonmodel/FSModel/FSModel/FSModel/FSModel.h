//
//  FSModel.h
//  FSModel
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FSKeyMapper;
//MARK: - 属性可以遵守的协议，用来判断属性是否可选和忽略
@protocol Optional
@end

@protocol Ignore
@end

//MARK: -  FSModel必须遵守的协议，可以作为接口提供给FSModel的子类
@protocol FSModelAbstractProtocol <NSCopying, NSCoding, NSSecureCoding>
@required
- (instancetype)initWithDictionary:(NSDictionary *)dictionary error:(NSError *__autoreleasing*)err;
- (instancetype)initWithString:(NSString *)jsonString error:(NSError *__autoreleasing*)err;
- (instancetype)initWithData:(NSData *)jsonData error:(NSError *__autoreleasing*)err;
- (NSDictionary *)toDictionary;
- (NSDictionary *)toDictionaryWithPropertyNames:(NSArray *)propertyNames;

@end

@interface FSModel : NSObject<FSModelAbstractProtocol>
//MARK: -初始化方法
- (instancetype)initWithString:(NSString *)jsonString usingEncoding:(NSStringEncoding)encoding error:(NSError *__autoreleasing *)err;
//MARK: -转换方法
- (NSString *)toJSONString;
- (NSString *)toJSONStringWithPropertyNames:(NSArray *)propertyNames;
- (NSData *)toJSONData;
- (NSData *)toJSONDataWithPropertyNames:(NSArray *)propertyNames;

//MARK: -在必要的时候需要子类重写的
+ (BOOL)propertyIsOptional:(NSString *)propertyName;
+ (BOOL)propertyIsIgnored:(NSString *)propertyName;
+ (FSKeyMapper *)keyMapper;

//MARK:-模型集合的转化
+ (NSMutableArray *)arrayOfModelsForArray:(NSArray *)array error:(NSError **)error;
@end
