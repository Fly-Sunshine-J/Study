//
//  JSONModel.m
//  JSONModel
//

#if !__has_feature(objc_arc)
#error The JSONMOdel framework is ARC only, you can enable ARC on per file basis.
#endif


#import <objc/runtime.h>
#import <objc/message.h>


#import "JSONModel.h"
#import "JSONModelClassProperty.h"

#pragma mark - associated objects names
static const char * kMapperObjectKey;
static const char * kClassPropertiesKey;
static const char * kClassRequiredPropertyNamesKey;
static const char * kIndexPropertyNameKey;

#pragma mark - class static variables
static NSArray* allowedJSONTypes = nil;
static NSArray* allowedPrimitiveTypes = nil;
static JSONValueTransformer* valueTransformer = nil;
static Class JSONModelClass = NULL;

#pragma mark - model cache
static JSONKeyMapper* globalKeyMapper = nil;

#pragma mark - JSONModel implementation
@implementation JSONModel
{
    NSString* _description;
}

#pragma mark - initialization methods

+(void)load
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // initialize all class static objects,
        // which are common for ALL JSONModel subclasses

        @autoreleasepool {
//          iOS支持的JSON类型
            allowedJSONTypes = @[
                [NSString class], [NSNumber class], [NSDecimalNumber class], [NSArray class], [NSDictionary class], [NSNull class], //immutable JSON classes
                [NSMutableString class], [NSMutableArray class], [NSMutableDictionary class] //mutable JSON classes
            ];
//          iOS支持的JSON基本数据类型
            allowedPrimitiveTypes = @[
                @"BOOL", @"float", @"int", @"long", @"double", @"short",
                @"unsigned int", @"usigned long", @"long long", @"unsigned long long", @"unsigned short", @"char", @"unsigned char",
                //and some famous aliases
                @"NSInteger", @"NSUInteger",
                @"Block"
            ];

            valueTransformer = [[JSONValueTransformer alloc] init];

            // This is quite strange, but I found the test isSubclassOfClass: (line ~291) to fail if using [JSONModel class].
            // somewhat related: https://stackoverflow.com/questions/6524165/nsclassfromstring-vs-classnamednsstring
            // //; seems to break the unit tests

            // Using NSClassFromString instead of [JSONModel class], as this was breaking unit tests, see below
            //http://stackoverflow.com/questions/21394919/xcode-5-unit-test-seeing-wrong-class
            JSONModelClass = NSClassFromString(NSStringFromClass(self));
        }
    });
}

-(void)__setup__
{
    //if first instance of this model, generate the property list
    if (!objc_getAssociatedObject(self.class, &kClassPropertiesKey)) {
//        检测属性的方法
        [self __inspectProperties];
    }

    //if there's a custom key mapper, store it in the associated object
//    关联JOSN的KEY和属性的=名的映射关系，并关联在类上，这里发现关联到类上使用OBJC_ASSOCIATION_RETAIN
    id mapper = [[self class] keyMapper];
    if ( mapper && !objc_getAssociatedObject(self.class, &kMapperObjectKey) ) {
        objc_setAssociatedObject(
                                 self.class,
                                 &kMapperObjectKey,
                                 mapper,
                                 OBJC_ASSOCIATION_RETAIN // This is atomic
                                 );
    }
}

-(id)init
{
    self = [super init];
    if (self) {
        //do initial class setup
        [self __setup__];
    }
    return self;
}

-(instancetype)initWithData:(NSData *)data error:(NSError *__autoreleasing *)err
{
    //check for nil input
//    检测二进制数据是不是空
    if (!data) {
        if (err) *err = [JSONModelError errorInputIsNil];
        return nil;
    }
    //read the json
//    对二进制JSON数据进行序列化
    JSONModelError* initError = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data
                                             options:kNilOptions
                                               error:&initError];
//    如果序列化失败
    if (initError) {
        if (err) *err = [JSONModelError errorBadJSON];
        return nil;
    }

    //init with dictionary
//    初始化模型
    id objModel = [self initWithDictionary:obj error:&initError];
    if (initError && err) *err = initError;
    return objModel;
}

-(id)initWithString:(NSString*)string error:(JSONModelError**)err
{
    JSONModelError* initError = nil;
    id objModel = [self initWithString:string usingEncoding:NSUTF8StringEncoding error:&initError];
    if (initError && err) *err = initError;
    return objModel;
}

-(id)initWithString:(NSString *)string usingEncoding:(NSStringEncoding)encoding error:(JSONModelError**)err
{
    //check for nil input
    if (!string) {
        if (err) *err = [JSONModelError errorInputIsNil];
        return nil;
    }

    JSONModelError* initError = nil;
    id objModel = [self initWithData:[string dataUsingEncoding:encoding] error:&initError];
    if (initError && err) *err = initError;
    return objModel;

}

-(id)initWithDictionary:(NSDictionary*)dict error:(NSError**)err
{
    //check for nil input
//    检查输入是否存在
    if (!dict) {
        if (err) *err = [JSONModelError errorInputIsNil];
        return nil;
    }

    //invalid input, just create empty instance
//    检查输入是否是字典
    if (![dict isKindOfClass:[NSDictionary class]]) {
        if (err) *err = [JSONModelError errorInvalidDataWithMessage:@"Attempt to initialize JSONModel object using initWithDictionary:error: but the dictionary parameter was not an 'NSDictionary'."];
        return nil;
    }

    //create a class instance
    self = [self init];
    if (!self) {

        //super init didn't succeed
        if (err) *err = [JSONModelError errorModelIsInvalid];
        return nil;
    }

    //check incoming data structure
//    检查字典的Key和模型属性之间的关系是否正确
    if (![self __doesDictionary:dict matchModelWithKeyMapper:self.__keyMapper error:err]) {
        return nil;
    }

    //import the data from a dictionary
    if (![self __importDictionary:dict withKeyMapper:self.__keyMapper validation:YES error:err]) {
        return nil;
    }

    //run any custom model validation
    if (![self validate:err]) {
        return nil;
    }

    //model is valid! yay!
    return self;
}

-(JSONKeyMapper*)__keyMapper
{
    //get the model key mapper
    return objc_getAssociatedObject(self.class, &kMapperObjectKey);
}


/**
 根据字典的Key和模型的属性以及映射关系keyMapper，在字典中能找到经过映射的key的Value，然后这些属性还是必须属性的子类才会返回YES

 @param dict 字典数据
 @param keyMapper 映射关系
 @param err 错误信息
 @return 是否可用
 */
-(BOOL)__doesDictionary:(NSDictionary*)dict matchModelWithKeyMapper:(JSONKeyMapper*)keyMapper error:(NSError**)err
{
    //check if all required properties are present
//    获取字典的key
    NSArray* incomingKeysArray = [dict allKeys];
//    获取必须的属性
    NSMutableSet* requiredProperties = [self __requiredPropertyNames].mutableCopy;
//    去除字典中重复的key
    NSSet* incomingKeys = [NSSet setWithArray: incomingKeysArray];

    //transform the key names, if necessary
//    开始映射
    if (keyMapper || globalKeyMapper) {

        NSMutableSet* transformedIncomingKeys = [NSMutableSet setWithCapacity: requiredProperties.count];
        NSString* transformedName = nil;

        //loop over the required properties list
//        遍历所有的属性并根据keyMapper映射出JSON中对应的key，然后检查数据中是否存在，如果存在获取属性名
        for (JSONModelClassProperty* property in [self __properties__]) {
//            根据属性名和映射关系keyMapper，找到JSON字典中对应的key
            transformedName = (keyMapper||globalKeyMapper) ? [self __mapString:property.name withKeyMapper:keyMapper] : property.name;

            //check if exists and if so, add to incoming keys
//            根据JSON中找到的key获取value，并添加到输入的key中
            id value;
            @try {
                value = [dict valueForKeyPath:transformedName];
            }
            @catch (NSException *exception) {
                value = dict[transformedName];
            }

            if (value) {
                [transformedIncomingKeys addObject: property.name];
            }
        }

        //overwrite the raw incoming list with the mapped key names
//
        incomingKeys = transformedIncomingKeys;
    }

    //check for missing input keys
//    检查丢失的属性
    if (![requiredProperties isSubsetOfSet:incomingKeys]) {

        //get a list of the missing properties
        [requiredProperties minusSet:incomingKeys];

        //not all required properties are in - invalid input
        JMLog(@"Incoming data was invalid [%@ initWithDictionary:]. Keys missing: %@", self.class, requiredProperties);

        if (err) *err = [JSONModelError errorInvalidDataWithMissingKeys:requiredProperties];
        return NO;
    }

    //not needed anymore
    incomingKeys= nil;
    requiredProperties= nil;

    return YES;
}


/**
 将属性名根据映射关系映射找到JSON中的key

 @param string 属性名
 @param keyMapper 映射关系
 @return JSON中的key
 */
-(NSString*)__mapString:(NSString*)string withKeyMapper:(JSONKeyMapper*)keyMapper
{
    if (keyMapper) {
        //custom mapper
        NSString* mappedName = [keyMapper convertValue:string];
        if (globalKeyMapper && [mappedName isEqualToString: string]) {
            mappedName = [globalKeyMapper convertValue:string];
        }
        string = mappedName;
    } else if (globalKeyMapper) {
        //global keymapper
        string = [globalKeyMapper convertValue:string];
    }

    return string;
}


/**
这个是字典和模型之间的映射，核心方法

 @param dict 字典
 @param keyMapper 映射关系
 @param validation 是否验证
 @param err 错误信息
 @return 返回是否映射成功
 */
-(BOOL)__importDictionary:(NSDictionary*)dict withKeyMapper:(JSONKeyMapper*)keyMapper validation:(BOOL)validation error:(NSError**)err
{
    //loop over the incoming keys and set self's properties
//    遍历所有的属性
    for (JSONModelClassProperty* property in [self __properties__]) {

        //convert key name to model keys, if a mapper is provided
//        根据keyMapper和属性名找到JSON字典中对应的key
        NSString* jsonKeyPath = (keyMapper||globalKeyMapper) ? [self __mapString:property.name withKeyMapper:keyMapper] : property.name;
        //JMLog(@"keyPath: %@", jsonKeyPath);

        //general check for data type compliance
//        根据key获取值
        id jsonValue;
        @try {
            jsonValue = [dict valueForKeyPath: jsonKeyPath];
        }
        @catch (NSException *exception) {
            jsonValue = dict[jsonKeyPath];
        }

        //check for Optional properties
//        检查Optional属性，如果value为nil或者NSNull
        if (isNull(jsonValue)) {
            //skip this property, continue with next property
//            如果该属性是可选属性，跳过
            if (property.isOptional || !validation) continue;
//            如果是必选属性，而JSON字典中没有这个值，抛出错误
            if (err) {
                //null value for required property
                NSString* msg = [NSString stringWithFormat:@"Value of required model key %@ is null", property.name];
                JSONModelError* dataErr = [JSONModelError errorInvalidDataWithMessage:msg];
                *err = [dataErr errorByPrependingKeyPathComponent:property.name];
            }
            return NO;
        }
//        获取value的类型
        Class jsonValueClass = [jsonValue class];
        BOOL isValueOfAllowedType = NO;
//        获取value是不是iOS中JSON允许的类型
        for (Class allowedType in allowedJSONTypes) {
            if ( [jsonValueClass isSubclassOfClass: allowedType] ) {
                isValueOfAllowedType = YES;
                break;
            }
        }
//        如果value不是iOS中JSON允许的类型，抛出错误
        if (isValueOfAllowedType==NO) {
            //type not allowed
            JMLog(@"Type %@ is not allowed in JSON.", NSStringFromClass(jsonValueClass));

            if (err) {
                NSString* msg = [NSString stringWithFormat:@"Type %@ is not allowed in JSON.", NSStringFromClass(jsonValueClass)];
                JSONModelError* dataErr = [JSONModelError errorInvalidDataWithMessage:msg];
                *err = [dataErr errorByPrependingKeyPathComponent:property.name];
            }
            return NO;
        }

        //check if there's matching property in the model
//        模型匹配
        if (property) {

            // check for custom setter, than the model doesn't need to do any guessing
            // how to read the property's value from JSON
//            检测自定义的setter方法为这个属性，如果有自定义的setter方法，找到这个方法并调用，然后返回YES，跳过
            if ([self __customSetValue:jsonValue forProperty:property]) {
                //skip to next JSON key
                continue;
            };
            // 0) handle primitives
//            如果是基础数据
            if (property.type == nil && property.structName==nil) {

                //generic setter
//                为属性赋值
                if (jsonValue != [self valueForKey:property.name]) {
                    [self setValue:jsonValue forKey: property.name];
                }

                //skip directly to the next key
                continue;
            }

            // 0.5) handle nils
//            如果是nil，置空处理
            if (isNull(jsonValue)) {
                if ([self valueForKey:property.name] != nil) {
                    [self setValue:nil forKey: property.name];
                }
                continue;
            }


            // 1) check if property is itself a JSONModel
//            判断当前属性的类型是不是JSONModel的子类
            if ([self __isJSONModelSubClass:property.type]) {

                //initialize the property's model, store it
                JSONModelError* initErr = nil;
//                调用方法生成一个对象
                id value = [[property.type alloc] initWithDictionary: jsonValue error:&initErr];

                if (!value) {
                    //skip this property, continue with next property
//                    如果属性可选，继续下一个属性，如果不是 抛出异常
                    if (property.isOptional || !validation) continue;

                    // Propagate the error, including the property name as the key-path component
                    if((err != nil) && (initErr != nil))
                    {
                        *err = [initErr errorByPrependingKeyPathComponent:property.name];
                    }
                    return NO;
                }
                if (![value isEqual:[self valueForKey:property.name]]) {
                    [self setValue:value forKey: property.name];
                }

                //for clarity, does the same without continue
                continue;

            } else {

                // 2) check if there's a protocol to the property
                //  ) might or not be the case there's a built in transform for it
                if (property.protocol) {

                    //JMLog(@"proto: %@", p.protocol);
//                    根据属性将jsonvalue转化成模型数组或者模型字典
                    jsonValue = [self __transform:jsonValue forProperty:property error:err];
                    if (!jsonValue) {
//                        转化失败，抛出异常
                        if ((err != nil) && (*err == nil)) {
                            NSString* msg = [NSString stringWithFormat:@"Failed to transform value, but no error was set during transformation. (%@)", property];
                            JSONModelError* dataErr = [JSONModelError errorInvalidDataWithMessage:msg];
                            *err = [dataErr errorByPrependingKeyPathComponent:property.name];
                        }
                        return NO;
                    }
                }

                // 3.1) handle matching standard JSON types
//                处理标准的JSON类型，并且jsonvalue是属性的类型
                if (property.isStandardJSONType && [jsonValue isKindOfClass: property.type]) {

                    //mutable properties
                    if (property.isMutable) {
                        jsonValue = [jsonValue mutableCopy];
                    }

                    //set the property value
                    if (![jsonValue isEqual:[self valueForKey:property.name]]) {
                        [self setValue:jsonValue forKey: property.name];
                    }
                    continue;
                }

                // 3.3) handle values to transform
//                处理数据的转化，因为JSON序列化不可能会序列出可变的、结构体、基本的数据类型
                if (
                    (![jsonValue isKindOfClass:property.type] && !isNull(jsonValue))
                    ||
                    //the property is mutable
                    property.isMutable
                    ||
                    //custom struct property
                    property.structName
                    ) {

                    // searched around the web how to do this better
                    // but did not find any solution, maybe that's the best idea? (hardly)
                    Class sourceClass = [JSONValueTransformer classByResolvingClusterClasses:[jsonValue class]];

                    //JMLog(@"to type: [%@] from type: [%@] transformer: [%@]", p.type, sourceClass, selectorName);

                    //build a method selector for the property and json object classes
                    NSString* selectorName = [NSString stringWithFormat:@"%@From%@:",
                                              (property.structName? property.structName : property.type), //target name
                                              sourceClass]; //source name
                    SEL selector = NSSelectorFromString(selectorName);

                    //check for custom transformer
//                    检查JSONValueTransformer类中是否存在响应的转换方法
                    BOOL foundCustomTransformer = NO;
                    if ([valueTransformer respondsToSelector:selector]) {
                        foundCustomTransformer = YES;
                    } else {
                        //try for hidden custom transformer
                        selectorName = [NSString stringWithFormat:@"__%@",selectorName];
                        selector = NSSelectorFromString(selectorName);
                        if ([valueTransformer respondsToSelector:selector]) {
                            foundCustomTransformer = YES;
                        }
                    }

                    //check if there's a transformer with that name
//                    如果存在转换方法，因为可能存在私有方法，这个时候要获取的函数的实现IMP指针，调用
                    if (foundCustomTransformer) {
                        IMP imp = [valueTransformer methodForSelector:selector];
                        id (*func)(id, SEL, id) = (void *)imp;
                        jsonValue = func(valueTransformer, selector, jsonValue);

                        if (![jsonValue isEqual:[self valueForKey:property.name]])
                            [self setValue:jsonValue forKey:property.name];
                    } else {
//                        如果转换方法不存在，抛出错误
                        if (err) {
                            NSString* msg = [NSString stringWithFormat:@"%@ type not supported for %@.%@", property.type, [self class], property.name];
                            JSONModelError* dataErr = [JSONModelError errorInvalidDataWithTypeMismatch:msg];
                            *err = [dataErr errorByPrependingKeyPathComponent:property.name];
                        }
                        return NO;
                    }
                } else {
                    // 3.4) handle "all other" cases (if any)
                    if (![jsonValue isEqual:[self valueForKey:property.name]])
                        [self setValue:jsonValue forKey:property.name];
                }
            }
        }
    }

    return YES;
}

#pragma mark - property inspection methods

-(BOOL)__isJSONModelSubClass:(Class)class
{
// http://stackoverflow.com/questions/19883472/objc-nsobject-issubclassofclass-gives-incorrect-failure
#ifdef UNIT_TESTING
    return [@"JSONModel" isEqualToString: NSStringFromClass([class superclass])];
#else
    return [class isSubclassOfClass:JSONModelClass];
#endif
}

//returns a set of the required keys for the model
// 获取模型必须的属性名
-(NSMutableSet*)__requiredPropertyNames
{
    //fetch the associated property names
    NSMutableSet* classRequiredPropertyNames = objc_getAssociatedObject(self.class, &kClassRequiredPropertyNamesKey);

    if (!classRequiredPropertyNames) {
        classRequiredPropertyNames = [NSMutableSet set];
        [[self __properties__] enumerateObjectsUsingBlock:^(JSONModelClassProperty* p, NSUInteger idx, BOOL *stop) {
            if (!p.isOptional) [classRequiredPropertyNames addObject:p.name];
        }];

        //persist the list
        objc_setAssociatedObject(
                                 self.class,
                                 &kClassRequiredPropertyNamesKey,
                                 classRequiredPropertyNames,
                                 OBJC_ASSOCIATION_RETAIN // This is atomic
                                 );
    }
    return classRequiredPropertyNames;
}

//returns a list of the model's properties
// 获取模型的所有属性
-(NSArray*)__properties__
{
    //fetch the associated object
    NSDictionary* classProperties = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    if (classProperties) return [classProperties allValues];

    //if here, the class needs to inspect itself
    [self __setup__];

    //return the property list
    classProperties = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    return [classProperties allValues];
}

//inspects the class, get's a list of the class properties
//检测这个类的属性的方法
-(void)__inspectProperties
{
    //JMLog(@"Inspect class: %@", [self class]);

    NSMutableDictionary* propertyIndex = [NSMutableDictionary dictionary];

    //temp variables for the loops
//    获取当前的类
    Class class = [self class];
    NSScanner* scanner = nil;
    NSString* propertyType = nil;

    // inspect inherited properties up to the JSONModel class
//    由于JSONModel使用方法就是继承JSONModel，如果当前类不是JSONModel，进入循环
    while (class != [JSONModel class]) {
        //JMLog(@"inspecting: %@", NSStringFromClass(class));

//        获取属性列表
        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList(class, &propertyCount);

        //loop over the class properties
//        遍历属性列表
        for (unsigned int i = 0; i < propertyCount; i++) {

            JSONModelClassProperty* p = [[JSONModelClassProperty alloc] init];

            //get property name
//            获取属性名
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            p.name = @(propertyName);

            //JMLog(@"property: %@", p.name);

            //get property attributes
//            获取属性的特性
            const char *attrs = property_getAttributes(property);
            NSString* propertyAttributes = @(attrs);
            NSArray* attributeItems = [propertyAttributes componentsSeparatedByString:@","];

            //ignore read-only properties
//            T@"ImageModel",&,N,V_singleImage T代表类型 &代表内存管理方式retain N代表nonatomic,V代表成员变量 如果是只读属性，过滤调
            if ([attributeItems containsObject:@"R"]) {
                continue; //to next property
            }

            scanner = [NSScanner scannerWithString: propertyAttributes];

            //JMLog(@"attr: %@", [NSString stringWithCString:attrs encoding:NSUTF8StringEncoding]);
//            如果字符串第一个就是要找到字符串，这个会将scanLocation定位到参数string的前面，也就是0的位置，并且返回NO
            [scanner scanUpToString:@"T" intoString: nil];
//            和上面的方法刚好有点差距，这个会将scanLocation定位到参数string后面，也就是参数scanLocation + string.lenth的位置，并且返回YES
            [scanner scanString:@"T" intoString:nil];

            //check if the property is an instance of a class
//            如果属性是一个类
            if ([scanner scanString:@"@\"" intoString: &propertyType]) {
//                获取类名
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&propertyType];

                //JMLog(@"type: %@", propertyClassName);
                p.type = NSClassFromString(propertyType);
//                判断是不是可变的
                p.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
//                判断是不是标准的JSON类型
                p.isStandardJSONType = [allowedJSONTypes containsObject:p.type];

                //read through the property protocols
//                获取对象遵守的协议，这里使用循环是因为可能会出现这样的属性@protrty (nonatomic, strong) NSArray<NSString *><Optional> array;
                while ([scanner scanString:@"<" intoString:NULL]) {

                    NSString* protocolName = nil;

                    [scanner scanUpToString:@">" intoString: &protocolName];

                    if ([protocolName isEqualToString:@"Optional"]) {
//                      如果遵守的协议时可选的
                        p.isOptional = YES;
                    } else if([protocolName isEqualToString:@"Index"]) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                        p.isIndex = YES;
#pragma GCC diagnostic pop

                        objc_setAssociatedObject(
                                                 self.class,
                                                 &kIndexPropertyNameKey,
                                                 p.name,
                                                 OBJC_ASSOCIATION_RETAIN // This is atomic
                                                 );
                    } else if([protocolName isEqualToString:@"Ignore"]) {
//                        如果遵守的协议时Ignore
                        p = nil;
                    } else {
                        p.protocol = protocolName;
                    }

                    [scanner scanString:@">" intoString:NULL];
                }

            }
            //check if the property is a structure
//            如果属性是一个结构体
            else if ([scanner scanString:@"{" intoString: &propertyType]) {
                [scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
                                    intoString:&propertyType];

                p.isStandardJSONType = NO;
                p.structName = propertyType;

            }
            //the property must be a primitive
//            如果属性是一个基本数据
            else {

                //the property contains a primitive data type
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@","]
                                        intoString:&propertyType];

                //get the full name of the primitive type
                propertyType = valueTransformer.primitivesNames[propertyType];

                if (![allowedPrimitiveTypes containsObject:propertyType]) {

                    //type not allowed - programmer mistaken -> exception
                    @throw [NSException exceptionWithName:@"JSONModelProperty type not allowed"
                                                   reason:[NSString stringWithFormat:@"Property type of %@.%@ is not supported by JSONModel.", self.class, p.name]
                                                 userInfo:nil];
                }

            }

            NSString *nsPropertyName = @(propertyName);
//            如果子类重写propertyIsOptional该方法，返回YES，则该属性是可选类型
            if([[self class] propertyIsOptional:nsPropertyName]){
                p.isOptional = YES;
            }
//            如果子类重写propertyIsIgnored该方法，返回YES，则该属性是忽略类型
            if([[self class] propertyIsIgnored:nsPropertyName]){
                p = nil;
            }

            Class customClass = [[self class] classForCollectionProperty:nsPropertyName];
            if (customClass) {
                p.protocol = NSStringFromClass(customClass);
            }

            //few cases where JSONModel will ignore properties automatically
//            Block类型的属性自动忽略
            if ([propertyType isEqualToString:@"Block"]) {
                p = nil;
            }

            //add the property object to the temp index
//            将属性实例根据属性名添加到字典中
            if (p && ![propertyIndex objectForKey:p.name]) {
                [propertyIndex setValue:p forKey:p.name];
            }

            // generate custom setters and getter
//            生成自定义的getter和setter
            if (p)
            {
                NSString *name = [p.name stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[p.name substringToIndex:1].uppercaseString];

                // getter
                SEL getter = NSSelectorFromString([NSString stringWithFormat:@"JSONObjectFor%@", name]);

                if ([self respondsToSelector:getter])
                    p.customGetter = getter;

                // setters
                p.customSetters = [NSMutableDictionary new];

                SEL genericSetter = NSSelectorFromString([NSString stringWithFormat:@"set%@WithJSONObject:", name]);

                if ([self respondsToSelector:genericSetter])
                    p.customSetters[@"generic"] = [NSValue valueWithBytes:&genericSetter objCType:@encode(SEL)];

                for (Class type in allowedJSONTypes)
                {
                    NSString *class = NSStringFromClass([JSONValueTransformer classByResolvingClusterClasses:type]);

                    if (p.customSetters[class])
                        continue;

                    SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@With%@:", name, class]);

                    if ([self respondsToSelector:setter])
                        p.customSetters[class] = [NSValue valueWithBytes:&setter objCType:@encode(SEL)];
                }
            }
        }

        free(properties);

        //ascend to the super of the class
        //(will do that until it reaches the root class - JSONModel)
        class = [class superclass];
    }

    //finally store the property index in the static property index
//    将属性的信息关联到类上，这样可以防止多次调用，这里发现关联到类上使用OBJC_ASSOCIATION_RETAIN
    objc_setAssociatedObject(
                             self.class,
                             &kClassPropertiesKey,
                             [propertyIndex copy],
                             OBJC_ASSOCIATION_RETAIN // This is atomic
                             );
}

#pragma mark - built-in transformer methods
//few built-in transformations
// 根据属性的协议进行转化
-(id)__transform:(id)value forProperty:(JSONModelClassProperty*)property error:(NSError**)err
{
    Class protocolClass = NSClassFromString(property.protocol);
//    如果根据协议生成的类不存在，直接返回value
    if (!protocolClass) {

        //no other protocols on arrays and dictionaries
        //except JSONModel classes
//        如果value是数组的子类，而且声明的协议类不存在，抛出异常
        if ([value isKindOfClass:[NSArray class]]) {
            @throw [NSException exceptionWithName:@"Bad property protocol declaration"
                                           reason:[NSString stringWithFormat:@"<%@> is not allowed JSONModel property protocol, and not a JSONModel class.", property.protocol]
                                         userInfo:nil];
        }
        return value;
    }

    //if the protocol is actually a JSONModel class
//    如果协议类是JSONModel的子类
    if ([self __isJSONModelSubClass:protocolClass]) {

        //check if it's a list of models
//      如果属性类型是数组的子类
        if ([property.type isSubclassOfClass:[NSArray class]]) {

            // Expecting an array, make sure 'value' is an array
//            如果value的类型不是数组抛出异常
            if(![[value class] isSubclassOfClass:[NSArray class]])
            {
                if(err != nil)
                {
                    NSString* mismatch = [NSString stringWithFormat:@"Property '%@' is declared as NSArray<%@>* but the corresponding JSON value is not a JSON Array.", property.name, property.protocol];
                    JSONModelError* typeErr = [JSONModelError errorInvalidDataWithTypeMismatch:mismatch];
                    *err = [typeErr errorByPrependingKeyPathComponent:property.name];
                }
                return nil;
            }

            //one shot conversion
            JSONModelError* arrayErr = nil;
//            根据协议类将数组转化为模型数组
            value = [[protocolClass class] arrayOfModelsFromDictionaries:value error:&arrayErr];
            if((err != nil) && (arrayErr != nil))
            {
                *err = [arrayErr errorByPrependingKeyPathComponent:property.name];
                return nil;
            }
        }

        //check if it's a dictionary of models
//        如果属性类型是字典的子类并且遵守协议，该协议用在字典的value上
        if ([property.type isSubclassOfClass:[NSDictionary class]]) {

            // Expecting a dictionary, make sure 'value' is a dictionary
            if(![[value class] isSubclassOfClass:[NSDictionary class]])
//                如果value不是字典，抛出异常
            {
                if(err != nil)
                {
                    NSString* mismatch = [NSString stringWithFormat:@"Property '%@' is declared as NSDictionary<%@>* but the corresponding JSON value is not a JSON Object.", property.name, property.protocol];
                    JSONModelError* typeErr = [JSONModelError errorInvalidDataWithTypeMismatch:mismatch];
                    *err = [typeErr errorByPrependingKeyPathComponent:property.name];
                }
                return nil;
            }

            NSMutableDictionary* res = [NSMutableDictionary dictionary];
//            遍历字典
            for (NSString* key in [value allKeys]) {
                JSONModelError* initErr = nil;
//                根据字典的value生成对象
                id obj = [[[protocolClass class] alloc] initWithDictionary:value[key] error:&initErr];
                if (obj == nil)
                {
                    // Propagate the error, including the property name as the key-path component
                    if((err != nil) && (initErr != nil))
                    {
                        initErr = [initErr errorByPrependingKeyPathComponent:key];
                        *err = [initErr errorByPrependingKeyPathComponent:property.name];
                    }
                    return nil;
                }
//                组成字典
                [res setValue:obj forKey:key];
            }
            value = [NSDictionary dictionaryWithDictionary:res];
        }
    }

    return value;
}

//built-in reverse transformations (export to JSON compliant objects)
//  将模型数组或字典转化为普通的数组或字典
-(id)__reverseTransform:(id)value forProperty:(JSONModelClassProperty*)property
{
    Class protocolClass = NSClassFromString(property.protocol);
    if (!protocolClass) return value;

    //if the protocol is actually a JSONModel class
    if ([self __isJSONModelSubClass:protocolClass]) {

        //check if should export list of dictionaries
        if (property.type == [NSArray class] || property.type == [NSMutableArray class]) {
            NSMutableArray* tempArray = [NSMutableArray arrayWithCapacity: [(NSArray*)value count] ];
            for (NSObject<AbstractJSONModelProtocol>* model in (NSArray*)value) {
                if ([model respondsToSelector:@selector(toDictionary)]) {
                    [tempArray addObject: [model toDictionary]];
                } else
                    [tempArray addObject: model];
            }
            return [tempArray copy];
        }

        //check if should export dictionary of dictionaries
        if (property.type == [NSDictionary class] || property.type == [NSMutableDictionary class]) {
            NSMutableDictionary* res = [NSMutableDictionary dictionary];
            for (NSString* key in [(NSDictionary*)value allKeys]) {
                id<AbstractJSONModelProtocol> model = value[key];
                [res setValue: [model toDictionary] forKey: key];
            }
            return [NSDictionary dictionaryWithDictionary:res];
        }
    }

    return value;
}

#pragma mark - custom transformations
// 获取自定义的setter方法并执行返回YES，否则返回NO
- (BOOL)__customSetValue:(id <NSObject>)value forProperty:(JSONModelClassProperty *)property
{
    NSString *class = NSStringFromClass([JSONValueTransformer classByResolvingClusterClasses:[value class]]);

    SEL setter = nil;
    [property.customSetters[class] getValue:&setter];

    if (!setter)
        [property.customSetters[@"generic"] getValue:&setter];

    if (!setter)
        return NO;

    IMP imp = [self methodForSelector:setter];
    void (*func)(id, SEL, id <NSObject>) = (void *)imp;
    func(self, setter, value);

    return YES;
}

//获取自定义的setter方法并执行，返回YES，否则返回NO
- (BOOL)__customGetValue:(id *)value forProperty:(JSONModelClassProperty *)property
{
    SEL getter = property.customGetter;

    if (!getter)
        return NO;

    IMP imp = [self methodForSelector:getter];
    id (*func)(id, SEL) = (void *)imp;
    *value = func(self, getter);

    return YES;
}

#pragma mark - persistance
//由于可以通过keyPath中的.的方式来给属性的属性进行赋值
-(void)__createDictionariesForKeyPath:(NSString*)keyPath inDictionary:(NSMutableDictionary**)dict
{
    //find if there's a dot left in the keyPath
    NSUInteger dotLocation = [keyPath rangeOfString:@"."].location;
    if (dotLocation==NSNotFound) return;

    //inspect next level
    NSString* nextHierarchyLevelKeyName = [keyPath substringToIndex: dotLocation];
    NSDictionary* nextLevelDictionary = (*dict)[nextHierarchyLevelKeyName];

    if (nextLevelDictionary==nil) {
        //create non-existing next level here
        nextLevelDictionary = [NSMutableDictionary dictionary];
    }

    //recurse levels
//    递归调用  直到最后
    [self __createDictionariesForKeyPath:[keyPath substringFromIndex: dotLocation+1]
                            inDictionary:&nextLevelDictionary ];

    //create the hierarchy level
    [*dict setValue:nextLevelDictionary  forKeyPath: nextHierarchyLevelKeyName];
}
// 模型转字典
-(NSDictionary*)toDictionary
{
    return [self toDictionaryWithKeys:nil];
}
//模型转字符串
-(NSString*)toJSONString
{
    return [self toJSONStringWithKeys:nil];
}
//模型转二进制
-(NSData*)toJSONData
{
    return [self toJSONDataWithKeys:nil];
}

//exports the model as a dictionary of JSON compliant objects
// 根据属性名模型转字典
-(NSDictionary*)toDictionaryWithKeys:(NSArray*)propertyNames
{
//    获取所有的属性信息
    NSArray* properties = [self __properties__];
    NSMutableDictionary* tempDictionary = [NSMutableDictionary dictionaryWithCapacity:properties.count];

    id value;

    //loop over all properties
    for (JSONModelClassProperty* p in properties) {

        //skip if unwanted
//        如果属性参数存在但是不包含在属性名中，跳过
        if (propertyNames != nil && ![propertyNames containsObject:p.name])
            continue;

        //fetch key and value
//        获取映射之前的keyPath
        NSString* keyPath = (self.__keyMapper||globalKeyMapper) ? [self __mapString:p.name withKeyMapper:self.__keyMapper] : p.name;
//        获取属性的值
        value = [self valueForKey: p.name];

        //JMLog(@"toDictionary[%@]->[%@] = '%@'", p.name, keyPath, value);
//        如果keyPath存在属性的属性形式，生成字典
        if ([keyPath rangeOfString:@"."].location != NSNotFound) {
            //there are sub-keys, introduce dictionaries for them
            [self __createDictionariesForKeyPath:keyPath inDictionary:&tempDictionary];
        }

        //check for custom getter
//        根据自定义的getter方法获取value
        if ([self __customGetValue:&value forProperty:p]) {
            //custom getter, all done
            [tempDictionary setValue:value forKeyPath:keyPath];
            continue;
        }

        //export nil when they are not optional values as JSON null, so that the structure of the exported data
        //is still valid if it's to be imported as a model again
        if (isNull(value)) {

            if (value == nil)
            {
                //        如果获取的value是nil 移除
                [tempDictionary removeObjectForKey:keyPath];
            }
            else
            {
//                如果是NSNull 设置NSNull
                [tempDictionary setValue:[NSNull null] forKeyPath:keyPath];
            }
            continue;
        }

        //check if the property is another model
//        如果value是JSONModel的子类
        if ([value isKindOfClass:JSONModelClass]) {

            //recurse models
//            递归调用，知道value不是JSONModel的子类
            value = [(JSONModel*)value toDictionary];
            [tempDictionary setValue:value forKeyPath: keyPath];

            //for clarity
            continue;

        } else {

            // 1) check for built-in transformation
//            如果存在协议，可能是数组或者字典，将这个模型数组或者字典转化为普通的模型数组或者字典
            if (p.protocol) {
                value = [self __reverseTransform:value forProperty:p];
            }

            // 2) check for standard types OR 2.1) primitives
//            如果是标准的JSON数据形式，直接设置
            if (p.structName==nil && (p.isStandardJSONType || p.type==nil)) {

                //generic get value
                [tempDictionary setValue:value forKeyPath: keyPath];

                continue;
            }

            // 3) try to apply a value transformer
//            如果没有自定义getter，使用JSONValueTransformer自带的转换方法
            if (YES) {

                //create selector from the property's class name
                NSString* selectorName = [NSString stringWithFormat:@"%@From%@:", @"JSONObject", p.type?p.type:p.structName];
                SEL selector = NSSelectorFromString(selectorName);

                BOOL foundCustomTransformer = NO;
                if ([valueTransformer respondsToSelector:selector]) {
                    foundCustomTransformer = YES;
                } else {
                    //try for hidden transformer
                    selectorName = [NSString stringWithFormat:@"__%@",selectorName];
                    selector = NSSelectorFromString(selectorName);
                    if ([valueTransformer respondsToSelector:selector]) {
                        foundCustomTransformer = YES;
                    }
                }

                //check if there's a transformer declared
                if (foundCustomTransformer) {
                    IMP imp = [valueTransformer methodForSelector:selector];
                    id (*func)(id, SEL, id) = (void *)imp;
                    value = func(valueTransformer, selector, value);

                    [tempDictionary setValue:value forKeyPath:keyPath];
                } else {
                    //in this case most probably a custom property was defined in a model
                    //but no default reverse transformer for it
                    @throw [NSException exceptionWithName:@"Value transformer not found"
                                                   reason:[NSString stringWithFormat:@"[JSONValueTransformer %@] not found", selectorName]
                                                 userInfo:nil];
                    return nil;
                }
            }
        }
    }

    return [tempDictionary copy];
}

//exports model to a dictionary and then to a JSON string
-(NSData*)toJSONDataWithKeys:(NSArray*)propertyNames
{
    NSData* jsonData = nil;
    NSError* jsonError = nil;

    @try {
        NSDictionary* dict = [self toDictionaryWithKeys:propertyNames];
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&jsonError];
    }
    @catch (NSException *exception) {
        //this should not happen in properly design JSONModel
        //usually means there was no reverse transformer for a custom property
        JMLog(@"EXCEPTION: %@", exception.description);
        return nil;
    }

    return jsonData;
}

-(NSString*)toJSONStringWithKeys:(NSArray*)propertyNames
{
    return [[NSString alloc] initWithData: [self toJSONDataWithKeys: propertyNames]
                                 encoding: NSUTF8StringEncoding];
}

#pragma mark - import/export of lists
//loop over an NSArray of JSON objects and turn them into models
//MARK:-普通数组转模型数组
+(NSMutableArray*)arrayOfModelsFromDictionaries:(NSArray*)array
{
    return [self arrayOfModelsFromDictionaries:array error:nil];
}

+ (NSMutableArray *)arrayOfModelsFromData:(NSData *)data error:(NSError **)err
{
    id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:err];
    if (!json || ![json isKindOfClass:[NSArray class]]) return nil;

    return [self arrayOfModelsFromDictionaries:json error:err];
}

+ (NSMutableArray *)arrayOfModelsFromString:(NSString *)string error:(NSError **)err
{
    return [self arrayOfModelsFromData:[string dataUsingEncoding:NSUTF8StringEncoding] error:err];
}

// Same as above, but with error reporting
//将普通数组转化为模型数组
+(NSMutableArray*)arrayOfModelsFromDictionaries:(NSArray*)array error:(NSError**)err
{
    //bail early
    if (isNull(array)) return nil;

    //parse dictionaries to objects
    NSMutableArray* list = [NSMutableArray arrayWithCapacity: [array count]];
//  遍历数组
    for (id d in array)
    {
        if ([d isKindOfClass:NSDictionary.class])
//            如果数组里面是字典
        {
            JSONModelError* initErr = nil;
//            生成对象
            id obj = [[self alloc] initWithDictionary:d error:&initErr];
            if (obj == nil)
            {
//                生成对象失败，抛出异常
                // Propagate the error, including the array index as the key-path component
                if((err != nil) && (initErr != nil))
                {
                    NSString* path = [NSString stringWithFormat:@"[%lu]", (unsigned long)list.count];
                    *err = [initErr errorByPrependingKeyPathComponent:path];
                }
                return nil;
            }

            [list addObject: obj];
        } else if ([d isKindOfClass:NSArray.class])
//            如果数组里面还是数组，递归该方法
        {
            [list addObjectsFromArray:[self arrayOfModelsFromDictionaries:d error:err]];
        } else
        {
            // This is very bad
        }

    }

    return list;
}
//MARK:-普通字典转模型字典
+ (NSMutableDictionary *)dictionaryOfModelsFromString:(NSString *)string error:(NSError **)err
{
    return [self dictionaryOfModelsFromData:[string dataUsingEncoding:NSUTF8StringEncoding] error:err];
}

+ (NSMutableDictionary *)dictionaryOfModelsFromData:(NSData *)data error:(NSError **)err
{
    id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:err];
    if (!json || ![json isKindOfClass:[NSDictionary class]]) return nil;

    return [self dictionaryOfModelsFromDictionary:json error:err];
}

+ (NSMutableDictionary *)dictionaryOfModelsFromDictionary:(NSDictionary *)dictionary error:(NSError **)err
{
    NSMutableDictionary *output = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

    for (NSString *key in dictionary.allKeys)
    {
        id object = dictionary[key];

        if ([object isKindOfClass:NSDictionary.class])
        {
            id obj = [[self alloc] initWithDictionary:object error:err];
            if (obj == nil) return nil;
            output[key] = obj;
        }
        else if ([object isKindOfClass:NSArray.class])
        {
            id obj = [self arrayOfModelsFromDictionaries:object error:err];
            if (obj == nil) return nil;
            output[key] = obj;
        }
        else
        {
            if (err) {
                *err = [JSONModelError errorInvalidDataWithTypeMismatch:@"Only dictionaries and arrays are supported"];
            }
            return nil;
        }
    }

    return output;
}

//loop over NSArray of models and export them to JSON objects
//MARK:-模型数组转普通数组
+(NSMutableArray*)arrayOfDictionariesFromModels:(NSArray*)array
{
    //bail early
    if (isNull(array)) return nil;

    //convert to dictionaries
    NSMutableArray* list = [NSMutableArray arrayWithCapacity: [array count]];

    for (id<AbstractJSONModelProtocol> object in array) {

        id obj = [object toDictionary];
        if (!obj) return nil;

        [list addObject: obj];
    }
    return list;
}

//loop over NSArray of models and export them to JSON objects with specific properties
+(NSMutableArray*)arrayOfDictionariesFromModels:(NSArray*)array propertyNamesToExport:(NSArray*)propertyNamesToExport;
{
    //bail early
    if (isNull(array)) return nil;

    //convert to dictionaries
    NSMutableArray* list = [NSMutableArray arrayWithCapacity: [array count]];

    for (id<AbstractJSONModelProtocol> object in array) {

        id obj = [object toDictionaryWithKeys:propertyNamesToExport];
        if (!obj) return nil;

        [list addObject: obj];
    }
    return list;
}
//MARK:-模型字典转普通字典
+(NSMutableDictionary *)dictionaryOfDictionariesFromModels:(NSDictionary *)dictionary
{
    //bail early
    if (isNull(dictionary)) return nil;

    NSMutableDictionary *output = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

    for (NSString *key in dictionary.allKeys) {
        id <AbstractJSONModelProtocol> object = dictionary[key];
        id obj = [object toDictionary];
        if (!obj) return nil;
        output[key] = obj;
    }

    return output;
}

#pragma mark - custom comparison methods

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
-(NSString*)indexPropertyName
{
    //custom getter for an associated object
    return objc_getAssociatedObject(self.class, &kIndexPropertyNameKey);
}

//
-(BOOL)isEqual:(id)object
{
    //bail early if different classes
    if (![object isMemberOfClass:[self class]]) return NO;

    if (self.indexPropertyName) {
        //there's a defined ID property
        id objectId = [object valueForKey: self.indexPropertyName];
        return [[self valueForKey: self.indexPropertyName] isEqual:objectId];
    }

    //default isEqual implementation
    return [super isEqual:object];
}

-(NSComparisonResult)compare:(id)object
{
    if (self.indexPropertyName) {
        id objectId = [object valueForKey: self.indexPropertyName];
        if ([objectId respondsToSelector:@selector(compare:)]) {
            return [[self valueForKey:self.indexPropertyName] compare:objectId];
        }
    }

    //on purpose postponing the asserts for speed optimization
    //these should not happen anyway in production conditions
    NSAssert(self.indexPropertyName, @"Can't compare models with no <Index> property");
    NSAssert1(NO, @"The <Index> property of %@ is not comparable class.", [self class]);
    return kNilOptions;
}

- (NSUInteger)hash
{
    if (self.indexPropertyName) {
        id val = [self valueForKey:self.indexPropertyName];

        if (val) {
            return [val hash];
        }
    }

    return [super hash];
}

#pragma GCC diagnostic pop

#pragma mark - custom data validation
-(BOOL)validate:(NSError**)error
{
    return YES;
}

#pragma mark - custom recursive description
//custom description method for debugging purposes
-(NSString*)description
{
    NSMutableString* text = [NSMutableString stringWithFormat:@"<%@> \n", [self class]];

    for (JSONModelClassProperty *p in [self __properties__]) {

        id value = ([p.name isEqualToString:@"description"])?self->_description:[self valueForKey:p.name];
        NSString* valueDescription = (value)?[value description]:@"<nil>";

        if (p.isStandardJSONType && ![value respondsToSelector:@selector(count)] && [valueDescription length]>60) {

            //cap description for longer values
            valueDescription = [NSString stringWithFormat:@"%@...", [valueDescription substringToIndex:59]];
        }
        valueDescription = [valueDescription stringByReplacingOccurrencesOfString:@"\n" withString:@"\n   "];
        [text appendFormat:@"   [%@]: %@\n", p.name, valueDescription];
    }

    [text appendFormat:@"</%@>", [self class]];
    return text;
}

#pragma mark - key mapping
+(JSONKeyMapper*)keyMapper
{
    return nil;
}

+(void)setGlobalKeyMapper:(JSONKeyMapper*)globalKeyMapperParam
{
    globalKeyMapper = globalKeyMapperParam;
}

+(BOOL)propertyIsOptional:(NSString*)propertyName
{
    return NO;
}

+(BOOL)propertyIsIgnored:(NSString *)propertyName
{
    return NO;
}

+(NSString*)protocolForArrayProperty:(NSString *)propertyName
{
    return nil;
}

+(Class)classForCollectionProperty:(NSString *)propertyName
{
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSString *protocolName = [self protocolForArrayProperty:propertyName];
#pragma GCC diagnostic pop

    if (!protocolName)
        return nil;

    return NSClassFromString(protocolName);
}

#pragma mark - working with incomplete models
- (void)mergeFromDictionary:(NSDictionary *)dict useKeyMapping:(BOOL)useKeyMapping
{
    [self mergeFromDictionary:dict useKeyMapping:useKeyMapping error:nil];
}

- (BOOL)mergeFromDictionary:(NSDictionary *)dict useKeyMapping:(BOOL)useKeyMapping error:(NSError **)error
{
    return [self __importDictionary:dict withKeyMapper:(useKeyMapping)? self.__keyMapper:nil validation:NO error:error];
}

#pragma mark - NSCopying, NSCoding
-(instancetype)copyWithZone:(NSZone *)zone
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:
        [NSKeyedArchiver archivedDataWithRootObject:self]
     ];
}

-(instancetype)initWithCoder:(NSCoder *)decoder
{
    NSString* json;

    if ([decoder respondsToSelector:@selector(decodeObjectOfClass:forKey:)]) {
        json = [decoder decodeObjectOfClass:[NSString class] forKey:@"json"];
    } else {
        json = [decoder decodeObjectForKey:@"json"];
    }

    JSONModelError *error = nil;
    self = [self initWithString:json error:&error];
    if (error) {
        JMLog(@"%@",[error localizedDescription]);
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.toJSONString forKey:@"json"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
