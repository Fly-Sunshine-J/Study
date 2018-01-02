//
//  FSModelClassProperty.m
//  FSModel
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "FSModelClassProperty.h"

@implementation FSModelClassProperty

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, %@", self.propertyName, self.protocolName];
}

@end
