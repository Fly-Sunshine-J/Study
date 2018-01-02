//
//  FSKeyMapper.h
//  FSModel
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSString *(^FSModelKeyMapperBlock)(NSString *propertyName);

@interface FSKeyMapper : NSObject

@property (nonatomic, copy, readonly) FSModelKeyMapperBlock keyMapperBlock;

- (instancetype)initWithModelKeyMapperBlock:(FSModelKeyMapperBlock)keyMapperBlock;
- (instancetype)initWithDictionary:(NSDictionary *)map;

- (NSString *)convertValue:(NSString *)propertyName;

@end
