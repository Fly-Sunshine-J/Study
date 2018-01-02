//
//  FSModelClassProperty.h
//  FSModel
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FSModelClassProperty : NSObject

@property (nonatomic, copy) NSString *propertyName;
@property (nonatomic, assign) Class type;
@property (nonatomic, copy) NSString *protocolName;
@property (nonatomic, assign) BOOL isOptional;
@property (nonatomic, assign) BOOL isStandaryJSONType;
@property (nonatomic, assign) BOOL isMutable;

@end
