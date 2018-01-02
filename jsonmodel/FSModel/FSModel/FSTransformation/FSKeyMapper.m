//
//  FSKeyMapper.m
//  FSModel
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "FSKeyMapper.h"

@implementation FSKeyMapper


- (instancetype)initWithModelKeyMapperBlock:(FSModelKeyMapperBlock)keyMapperBlock {
    self = [super init];
    if (self) {
        _keyMapperBlock = keyMapperBlock;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)map {
    self = [super init];
    if (self) {
        _keyMapperBlock = ^NSString *(NSString *propertyName) {
            return [map valueForKeyPath:propertyName] ?: propertyName;
        };
    }
    return self;
}


- (NSString *)convertValue:(NSString *)propertyName {
    return _keyMapperBlock(propertyName);
}


@end
