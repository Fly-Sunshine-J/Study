//
//  FSModel.m
//  FSModel
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "FSModel.h"
#import "FSKeyMapper.h"
#import "FSValueTransformer.h"
#import <objc/runtime.h>
#import "FSModelClassProperty.h"

// 关联对象使用
static const void *kClassPropertiesKey = &kClassPropertiesKey;
static const void *kClassRequiredPropertiesKey = &kClassRequiredPropertiesKey;
static const void *kClassKeyMapperKey = &kClassKeyMapperKey;

// 静态变量
static NSArray *allowJSONTypes = nil;
static NSArray *allowPrimitiveTypes = nil;
static FSValueTransformer *transformer = nil;
static Class FSModelClass = nil;


@implementation FSModel

+ (void)load {
    @autoreleasepool {
        allowJSONTypes = @[
                           [NSString class], [NSNumber class], [NSArray class],
                           [NSDictionary class], [NSDecimalNumber class],[NSNull class],
                           [NSMutableString class],[NSMutableArray class],[NSMutableDictionary class]];
        allowPrimitiveTypes = @[
                                @"BOOL", @"float", @"int", @"long", @"double", @"short",
                                @"unsigned int", @"usigned long", @"long long", @"unsigned long long", @"unsigned short", @"char", @"unsigned char",
                                //and some famous aliases
                                @"NSInteger", @"NSUInteger",
                                @"Block"
                                ];
        transformer = [[FSValueTransformer alloc] init];
        FSModelClass = NSClassFromString(NSStringFromClass(self));
    }
}


//MARK: -内部方法
- (void)__setup {
//    获取属性
    if (!objc_getAssociatedObject([self class], kClassPropertiesKey)) {
        [self __inspectProperties];
    }
    
    FSKeyMapper *mapper = [[self class] keyMapper];
    if (mapper && ![self __keyMapper]) {
        objc_setAssociatedObject([self class], kClassKeyMapperKey, mapper, OBJC_ASSOCIATION_RETAIN);
    }
}

- (FSKeyMapper *)__keyMapper {
    return objc_getAssociatedObject([self class], kClassKeyMapperKey);
}

-(void)__inspectProperties {
    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionary];
    
    Class class = [self class];
    NSString *propertyType = nil;
    NSScanner *scanner = nil;
    
    while (class != FSModelClass) {
        unsigned int outCount;
        objc_property_t *properties = class_copyPropertyList(class, &outCount);
        for (unsigned int i = 0; i < outCount; i++) {
            
            FSModelClassProperty *p = [[FSModelClassProperty alloc] init];
            
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            p.propertyName = @(propertyName);
            
            const char *attrs = property_getAttributes(property);
            NSString *attrsString = @(attrs);
            NSArray *attrItems = [attrsString componentsSeparatedByString:@","];
            if ([attrItems containsObject:@"R"]) {
                continue;
            }
            
            scanner = [NSScanner scannerWithString:attrsString];
            [scanner scanString:@"T" intoString:nil];
//            如果是类
            if ([scanner scanString:@"@\"" intoString:nil]) {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"<\""] intoString:&propertyType];
                p.type = NSClassFromString(propertyType);
                p.isMutable = [propertyType rangeOfString:@"Mutable"].location != NSNotFound;
                p.isStandaryJSONType = [allowJSONTypes containsObject:p.type];
                
                while ([scanner scanString:@"<" intoString:nil]) {
                    NSString *protocolName = nil;
                    [scanner scanUpToString:@">" intoString:&protocolName];
                    if ([protocolName isEqualToString:@"Optional"]) {
                        p.isOptional = YES;
                    }else if ([protocolName isEqualToString:@"Ignore"]) {
                        p = nil;
                        break;
                    }else {
                        p.protocolName = protocolName;
                    }
                    [scanner scanString:@">" intoString:NULL];
                }
            }else {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@","] intoString:&propertyType];
                propertyType = transformer.primitivesNames[propertyType];
                if (![allowPrimitiveTypes containsObject:propertyType]) {
                    @throw [NSException exceptionWithName:@"JSONModelProperty type not allowed"
                                                   reason:[NSString stringWithFormat:@"Property type of %@.%@ is not supported by JSONModel.", self.class, p.propertyName]
                                                 userInfo:nil];
                }
            }
            if (!p) {
                continue;
            }
            if ([propertyType isEqualToString:@"Block"]) {
                p = nil;
            }
            if ([[self class] propertyIsOptional:p.propertyName]) {
                p.isOptional = YES;
            }
            if ([[self class] propertyIsIgnored:p.propertyName] || [propertyType isEqualToString:@"Block"]) {
                p = nil;
            }
            
            if (p && ![propertyDictionary objectForKey:p.propertyName]) {
                [propertyDictionary setValue:p forKey:p.propertyName];
            }
        }
        free(properties);
        class = [class superclass];
    }
    objc_setAssociatedObject([self class], kClassPropertiesKey, propertyDictionary, OBJC_ASSOCIATION_RETAIN);
}


- (NSArray<FSModelClassProperty *> *)__properties {
    NSDictionary *properties = objc_getAssociatedObject([self class], kClassPropertiesKey);
    if (properties) {
        return [properties allValues];
    }
    [self __setup];
    properties = objc_getAssociatedObject([self class], kClassPropertiesKey);
    return [properties allValues];
    
}


- (NSSet<NSString *> *)__requirePropertiesNames {
    NSMutableSet *requirePorperties = objc_getAssociatedObject([self class], kClassRequiredPropertiesKey);
    if (!requirePorperties) {
        requirePorperties = [NSMutableSet set];
        [[self __properties] enumerateObjectsUsingBlock:^(FSModelClassProperty * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!obj.isOptional) {
                [requirePorperties addObject:obj.propertyName];
            }
        }];
        objc_setAssociatedObject([self class], kClassRequiredPropertiesKey, requirePorperties, OBJC_ASSOCIATION_RETAIN);
    }
    return requirePorperties.copy;
}

//根据keyMapper和属性检查字典
- (BOOL)__checkDictionary:(NSDictionary *)dict matchModelWithMapper:(FSKeyMapper *)mapper error:(NSError **)error {
    NSArray *inputKeyArray = [dict allKeys];
    NSMutableSet *requriedProperties = [self __requirePropertiesNames].mutableCopy;
    NSSet *inputKeySet = [NSSet setWithArray:inputKeyArray];
    if (mapper) {
        NSMutableSet *transformedKeys = [NSMutableSet setWithCapacity:requriedProperties.count];
        NSString *tranformedName = nil;
        for (FSModelClassProperty *p in [self __properties]) {
            tranformedName = [self __transformed:p.propertyName WithMapper:mapper];
            id value;
            @try {
                value = [dict valueForKeyPath:tranformedName];
            }@catch (NSException *e){
                value = dict[tranformedName];
            }
            if (value) {
                [transformedKeys addObject:p.propertyName];
            }
        }
        inputKeySet = transformedKeys;
    }
    if (![requriedProperties isSubsetOfSet:inputKeySet]) {
        [requriedProperties minusSet:inputKeySet];
        if (error) {
            *error = [NSError errorWithDomain:@"FSModel" code:1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid JSON data. Required JSON keys are missing {%@} from the input. Check the error user information", requriedProperties.description]}];
            return NO;
        }
    }
    
    
    return YES;
}

- (NSString *)__transformed:(NSString *)propertyName WithMapper:(FSKeyMapper *)mapper {
    if (mapper) {
        NSString *transformedKey = [mapper convertValue:propertyName];
        if (transformedKey) {
            return transformedKey;
        }
    }
    return propertyName;
}


- (BOOL)__importDictionaryForModel:(NSDictionary *)dictionary WithKeyMappler:(FSKeyMapper *)mapper eroor:(NSError **)error {
    for (FSModelClassProperty *p in [self __properties]) {
        NSString *dictionaryKey = mapper ? [self __transformed:p.propertyName WithMapper:mapper] : p.propertyName;
        id value;
        @try {
            value = [dictionary valueForKeyPath:dictionaryKey];
        }@catch(NSException *e) {
            value = dictionary[dictionaryKey];
        }
        if (isNull(value)) {
            if (p.isOptional) {
                if ([self valueForKeyPath:p.propertyName] != nil) {
                    [self setValue:value forKeyPath:p.propertyName];
                }
                continue;
            }else {
                if (error) {
                    *error = [NSError errorWithDomain:@"FSModel" code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"属性：%@是非可选的，请在字典内检查你的key：%@", p.propertyName, dictionaryKey]}];
                }
                return NO;
            }
        }
        
        Class valueClass = [value class];
        BOOL valueOfAllowedType = NO;
        for (Class allowType in allowJSONTypes) {
            if ([valueClass isSubclassOfClass:allowType]) {
                valueOfAllowedType = YES;
                break;
            }
        }
        if (!valueOfAllowedType) {
            *error = [NSError errorWithDomain:@"FSModel" code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"字典存在不能被iOS所允许的类型，请检查字典的Key:%@", dictionaryKey]}];
            return NO;
        }
        
        if (p.type == nil) {
            [self setValue:value forKeyPath:p.propertyName];
            continue;
        }
        if ([self __isFSModelSubClass:p.type]) {
            id subValue = [[p.type alloc] initWithDictionary:value error:error];
            if (!subValue) {
                if (p.isOptional) {
                    continue;
                }
                if (error) {
                    *error = [NSError errorWithDomain:@"FSModel" code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"子属性%@转化失败", p.propertyName]}];
                }
                return NO;
            }
            if (![subValue isEqual:[self valueForKey:p.propertyName]]) {
                [self setValue:subValue forKey:p.propertyName];
            }
            continue;
        }else {
            if (p.protocolName) {
                value = [self __transform:value forProperty:p error:error];
                if (!value) {
                    if (error) {
                        *error = [NSError errorWithDomain:@"FSModel" code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"转化失败%@", p.propertyName]}];
                    }
                    return NO;
                }
            }
            if (p.isStandaryJSONType && [value isKindOfClass:p.type]) {
                if (p.isMutable) {
                    value = [value mutableCopy];
                }
                [self setValue:value forKey:p.propertyName];
                continue;
            }
            
            if (
                (![value isKindOfClass:p.type] && !isNull(value))
                ||
                //the property is mutable
                p.isMutable
                ) {
                Class sourceClass = [FSValueTransformer classByResolvingClusterClasses:[value class]];
                NSString *selString = [NSString stringWithFormat:@"%@From%@:", p.type, sourceClass];
                SEL selestor = NSSelectorFromString(selString);
                if ([transformer respondsToSelector:selestor]) {
                    IMP imp = [transformer methodForSelector:selestor];
                    id (*fun)(id, SEL, id) = (void *)imp;
                    value = fun(transformer, selestor, value);
                    [self setValue:value forKey:p.propertyName];
                }else {
                    if (error) {
                        *error = [NSError errorWithDomain:@"FSModel" code:3 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"%@属性%@没有可用的转化方法", [self class], p.propertyName]}];
                    }
                    return NO;
                }
            }else {
                [self setValue:value forKey:p.propertyName];
            }
        }
    }
    return YES;
}

- (BOOL)__isFSModelSubClass:(Class)class {
    return [class isSubclassOfClass:FSModelClass];
}


- (id)__transform:(id)value forProperty:(FSModelClassProperty *)property error:(NSError **)error {
    Class protocolClass = NSClassFromString(property.protocolName);
    if (!protocolClass) {
        if ([value isKindOfClass:[NSArray class]]) {
            @throw [NSException exceptionWithName:@"Bad property protocol declaration"
                                           reason:[NSString stringWithFormat:@"<%@> is not allowed FSModel property protocol, and not a FSModel class.", property.protocolName]
                                         userInfo:nil];
        }
        return value;
    }
    if ([self __isFSModelSubClass:protocolClass]) {
        if ([property.type isSubclassOfClass:[NSArray class]] || [property.type isSubclassOfClass:[NSSet class]]) {
            if (![value isKindOfClass:[NSArray class]]) {
                if (error) {
                    *error = [NSError errorWithDomain:@"FSModel" code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"属性%@的类型被声明为%@ <%@>， 但是json对应的value不是一个数组类型", property.propertyName, property.type, property.protocolName]}];
                }
                return nil;
            }
            NSError *arrErr;
            value = [[protocolClass class] arrayOfModelsForArray:value error:&arrErr];
            if (arrErr) {
                return nil;
            }
        }else if ([property.type isSubclassOfClass:[NSDictionary class]]) {
            if (![[value class] isKindOfClass:[NSDictionary class]]) {
                if (error) {
                    *error = [NSError errorWithDomain:@"FSModel" code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"属性%@的类型被声明为NSDictionary <%@>， 但是json对应的value不是一个数组类型", property.propertyName, property.protocolName]}];
                }
                return nil;
            }
            
            NSMutableDictionary *res = [NSMutableDictionary dictionary];
            for (NSString *key in [value allKeys]) {
                NSError *initErr;
                id obj = [[[protocolClass class] alloc] initWithDictionary:value[key] error:&initErr];
                if (!obj) {
                    if (initErr != nil && error) {
                        *error = [NSError errorWithDomain:@"FSModel" code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"%@初始化失败%@", property.protocolName, key]}];
                    }
                    return nil;
                }
                [res setValue:obj forKey:key];
            }
            value = [res copy];
        }
    }
    return value;
}

//MARK: -FSModelAbstractProtocol
- (instancetype)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)err {
    if (!dictionary) {
        if (err) {
            *err = [NSError errorWithDomain:@"FSModel" code:0 userInfo:@{NSLocalizedDescriptionKey:@"输入源不能为空!"}];
        }
        return nil;
    }
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (err) {
            *err = [NSError errorWithDomain:@"FSModel" code:0 userInfo:@{NSLocalizedDescriptionKey:@"输入源必须是字典"}];
        }
        return nil;
    }
    self = [self init];
    if (!self) {
        *err = [NSError errorWithDomain:@"FSModel" code:0 userInfo:@{NSLocalizedDescriptionKey:@"模型属性出现问题不可用"}];
        return nil;
    }
    
    if (![self __checkDictionary:dictionary matchModelWithMapper:[self __keyMapper] error:err]) {
        return nil;
    }
    
    if (![self __importDictionaryForModel:dictionary WithKeyMappler:[self __keyMapper] eroor:err]) {
        return nil;
    }
    
    return self;
}

- (instancetype)initWithString:(NSString *)jsonString error:(NSError **)err {
    return self;
}

- (instancetype)initWithData:(NSData *)jsonData error:(NSError **)err {
    return self;
}
- (NSDictionary *)toDictionary {
    return [NSDictionary dictionary];
}

- (NSDictionary *)toDictionaryWithPropertyNames:(NSArray *)propertyNames {
    return [NSDictionary dictionary];

}

//MARK: -初始化方法

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self __setup];
    }
    return self;
}

- (instancetype)initWithString:(NSString *)jsonString usingEncoding:(NSStringEncoding)encoding error:(NSError *__autoreleasing *)err {
    return self;
}

//MARK: -转换方法
- (NSString *)toJSONString {
    return @"";
}
- (NSString *)toJSONStringWithPropertyNames:(NSArray *)propertyNames {
    return @"";
}
- (NSData *)toJSONData {
    return [NSData data];
}
- (NSData *)toJSONDataWithPropertyNames:(NSArray *)propertyNames {
    return [NSData data];
}

//MARK: -在必要的时候需要子类重写的
+ (BOOL)propertyIsOptional:(NSString *)propertyName {
    return NO;
}

+ (BOOL)propertyIsIgnored:(NSString *)propertyName {
    return NO;
}

+ (FSKeyMapper *)keyMapper {
    return nil;
}


//MARK:-模型集合的转化
+ (NSMutableArray *)arrayOfModelsForArray:(NSArray *)array error:(NSError **)error {
    if (isNull(array)) {
        return nil;
    }
    
    NSMutableArray *temArray = [NSMutableArray arrayWithCapacity:array.count];
    for (id value in array) {
        if ([value isKindOfClass:[NSDictionary class]]) {
            id obj = [[self alloc] initWithDictionary:value error:error];
            if (obj == nil) {
                if (error) {
                    
                    *error = [NSError errorWithDomain:@"FSModel" code:3 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"%@类生产失败", NSStringFromClass(self)]}];
                }
                return nil;
            }
            [temArray addObject:obj];
        }else if([value isKindOfClass:[NSArray class]]) {
            [temArray addObjectsFromArray:[self arrayOfModelsForArray:value error:error]];
        }
    }
    return temArray;
}

//MARK: - NSCopying, NSCoding, NSSecureCoding
- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
